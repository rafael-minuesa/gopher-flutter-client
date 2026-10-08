import {readFile, writeFile, mkdir, cp, rm} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {resolve, dirname, join} from 'node:path';
import {deflateSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const pkg = JSON.parse(await readFile(join(root, 'package.json'), 'utf8'));
const base = JSON.parse(await readFile(join(root, 'src/manifest.json'), 'utf8'));
const require = createRequire(import.meta.url);
const readability = dirname(require.resolve('@mozilla/readability/package.json'));

function crc(bytes) {
  let value = 0xffffffff;
  for (const byte of bytes) {
    value ^= byte;
    for (let i = 0; i < 8; i++) value = (value >>> 1) ^ (value & 1 ? 0xedb88320 : 0);
  }
  return (value ^ 0xffffffff) >>> 0;
}
function png(size) {
  const pixels = Buffer.alloc((size * 4 + 1) * size);
  const scale = size / 32;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const offset = y * (size * 4 + 1) + 1 + x * 4;
    const px = x / scale, py = y / scale;
    const chevron = px >= 7 && px <= 15 && Math.abs(py - (8 + (px - 7))) < 1.7 ||
      px >= 7 && px <= 15 && Math.abs(py - (24 - (px - 7))) < 1.7;
    const cursor = px >= 18 && px <= 25 && py >= 22 && py <= 24;
    const color = chevron || cursor ? [237, 244, 233, 255] : [32, 74, 60, 255];
    for (let c = 0; c < 4; c++) pixels[offset + c] = color[c];
  }
  function chunk(type, data) {
    const name = Buffer.from(type), length = Buffer.alloc(4), checksum = Buffer.alloc(4);
    length.writeUInt32BE(data.length); checksum.writeUInt32BE(crc(Buffer.concat([name, data])));
    return Buffer.concat([length, name, data, checksum]);
  }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(size); ihdr.writeUInt32BE(size, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(pixels)), chunk('IEND', Buffer.alloc(0))]);
}

await mkdir(join(root, 'dist'), {recursive: true});
for (const browser of ['chromium', 'firefox']) {
  const destination = join(root, 'dist', browser);
  await rm(destination, {recursive: true, force: true});
  await cp(join(root, 'src'), destination, {recursive: true});
  await mkdir(join(destination, 'vendor'), {recursive: true});
  await cp(join(readability, 'Readability.js'), join(destination, 'vendor/Readability.js'));
  await cp(join(readability, 'LICENSE.md'), join(destination, 'vendor/Readability.LICENSE.md'));
  await cp(join(root, '../LICENSE'), join(destination, 'LICENSE'));
  await mkdir(join(destination, 'icons'), {recursive: true});
  for (const size of [16, 32, 48, 128]) await writeFile(join(destination, 'icons', `${size}.png`), png(size));
  const manifest = {...base, version: pkg.version};
  if (browser === 'chromium') {
    manifest.minimum_chrome_version = '112';
    manifest.background = {service_worker: 'background.js'};
  } else {
    manifest.background = {scripts: ['core.js', 'background.js']};
    manifest.browser_specific_settings = {gecko: {id: 'gopher-reader@rafael-minuesa.github.io', strict_min_version: '142.0',
      data_collection_permissions: {required: ['none']}}};
  }
  await writeFile(join(destination, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  console.log(`Built ${browser} extension ${pkg.version}: ${destination}`);
  if (process.argv.includes('--package')) {
    await mkdir(join(root, 'artifacts'), {recursive: true});
    const archive = join(root, 'artifacts', `gopher-reader-${pkg.version}-${browser}.zip`);
    await rm(archive, {force: true});
    const result = spawnSync('zip', ['-q', '-r', archive, '.'], {cwd: destination, encoding: 'utf8'});
    if (result.status !== 0) throw new Error(result.stderr || 'Could not build ZIP package. Install zip and try again.');
    const digest = createHash('sha256').update(await readFile(archive)).digest('hex');
    await writeFile(archive + '.sha256', digest + '  ' + archive.split('/').pop() + '\n');
    console.log(`Packaged ${archive}`);
  }
}
