import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const repo = fileURLToPath(new URL('../', import.meta.url));
const androidSdk =
  process.env.ANDROID_HOME ||
  process.env.ANDROID_SDK_ROOT ||
  join(process.env.LOCALAPPDATA ?? '', 'Android', 'Sdk');
const adb = join(androidSdk, 'platform-tools', 'adb.exe');
const distro = process.env.KARDKHANA_WSL_DISTRO || 'Ubuntu';
const requestedAvd = process.env.KARDKHANA_AVD;
const pollIntervalMs = 2_000;

function capture(command, args, timeout = 15_000) {
  return execFileSync(command, args, {
    encoding: 'utf8',
    timeout,
    windowsHide: true,
  }).trim();
}

function runningEmulators() {
  return Array.from(
    capture(adb, ['devices']).matchAll(
      /^(emulator-\d+)\s+(device|offline|unauthorized)\b/gm,
    ),
    ([, serial, state]) => ({ serial, state }),
  );
}

function emulatorAbi(serial) {
  return capture(adb, ['-s', serial, 'shell', 'getprop', 'ro.product.cpu.abi']);
}

function matchesAvd(serial) {
  if (!requestedAvd) return true;
  try {
    const [name] = capture(adb, ['-s', serial, 'emu', 'avd', 'name']).split(/\r?\n/);
    return name === requestedAvd;
  } catch {
    return false;
  }
}

function emulatorBootId(serial) {
  try {
    const [booted, bootId = ''] = capture(adb, [
      '-s', serial, 'shell',
      'getprop sys.boot_completed; cat /proc/sys/kernel/random/boot_id 2>/dev/null || true',
    ]).split(/\r?\n/);
    return booted === '1' ? bootId : null;
  } catch {
    // ADB can disconnect briefly during boot.
    return null;
  }
}

async function readyEmulator(targetSerial) {
  const waitSeconds = 180;
  const deadline = Date.now() + waitSeconds * 1_000;
  const selection = requestedAvd ? `the ${requestedAvd} virtual phone` : 'a virtual phone';
  let emulators = [];
  let waitingReported = false;
  while (Date.now() < deadline) {
    emulators = runningEmulators().filter(({ serial }) =>
      targetSerial ? serial === targetSerial : matchesAvd(serial),
    );
    for (const { serial, state } of emulators) {
      if (state === 'device' && emulatorBootId(serial) !== null) return serial;
    }
    if (!waitingReported) {
      console.log(`Waiting up to ${waitSeconds} seconds for Android to boot. If the virtual phone is closed, press Ctrl+Shift+P in VS Code, run Emulator, and select ${selection}.`);
      waitingReported = true;
    }
    await delay(pollIntervalMs);
  }
  if (emulators.some(({ state }) => state === 'unauthorized')) {
    throw new Error('Approve Android debugging in the emulator window and run the task again.');
  }
  if (emulators.length === 0) {
    throw new Error(`ADB could not find ${selection}. Run Emulator from the VS Code Command Palette and check for a launch error.`);
  }
  throw new Error('The emulator did not finish booting. Check its window for an error.');
}

async function buildAndLaunch(serial) {
  const abi = emulatorAbi(serial);
  const target = { x86_64: 'android-x64', 'arm64-v8a': 'android-arm64' }[abi];
  if (!target) throw new Error(`Unsupported emulator CPU architecture: ${abi}`);

  const linuxRepo = capture('wsl.exe', ['-d', distro, '--exec', 'wslpath', '-a', '-u', repo]);
  const buildScript = readFileSync(join(repo, 'tools', 'build-emulator-apk.sh'), 'utf8')
    .replaceAll('\r\n', '\n');
  console.log(`Building KardKhana in ${distro} for ${abi}…`);
  execFileSync('wsl.exe', ['-d', distro, '--exec', 'bash', '-s', '--', linuxRepo, target], {
    input: buildScript,
    stdio: ['pipe', 'inherit', 'inherit'],
    windowsHide: true,
  });

  await readyEmulator(serial);
  if (emulatorAbi(serial) !== abi) {
    throw new Error('A different emulator architecture opened during the build. Run the task again.');
  }
  const apk = join(repo, 'app', 'build', 'emulator', 'app-debug.apk');
  console.log(capture(adb, ['-s', serial, 'install', '-r', apk], 120_000));
  const launch = capture(adb, [
    '-s', serial, 'shell', 'am', 'start', '-W', '-n',
    'np.edu.ku.kardkhana/.MainActivity',
  ], 30_000);
  if (!/^Status: ok$/m.test(launch.replaceAll('\r', ''))) {
    throw new Error(launch);
  }
  console.log(`KardKhana is open on ${serial}.`);
}

async function watchEmulators() {
  console.log('Launch an Android virtual phone through Emulator in the VS Code Command Palette. KardKhana will open when the build finishes.');
  const handledBoots = new Map();
  let warnedUnauthorized = false;

  while (true) {
    const emulators = runningEmulators().filter(({ serial }) => matchesAvd(serial));
    const unauthorized = emulators.some(({ state }) => state === 'unauthorized');
    if (unauthorized && !warnedUnauthorized) {
      console.error('Approve Android debugging in the emulator window to continue.');
    }
    warnedUnauthorized = unauthorized;

    for (const [serial, bootId] of handledBoots) {
      if (bootId === '' && !emulators.some(emulator => emulator.serial === serial)) {
        handledBoots.delete(serial);
      }
    }
    for (const { serial, state } of emulators) {
      if (state !== 'device') continue;
      const bootId = emulatorBootId(serial);
      if (bootId === null || handledBoots.get(serial) === bootId) continue;

      handledBoots.set(serial, bootId);
      try {
        await buildAndLaunch(serial);
      } catch (error) {
        console.error(`Could not open KardKhana on ${serial}: ${error.message}`);
      }
    }
    await delay(pollIntervalMs);
  }
}

async function main() {
  if (!existsSync(adb)) {
    throw new Error('Install Android SDK Platform-Tools.');
  }
  if (process.argv.includes('--watch')) {
    await watchEmulators();
  } else {
    await buildAndLaunch(await readyEmulator());
  }
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
