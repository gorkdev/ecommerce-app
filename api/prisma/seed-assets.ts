import { deflateSync } from 'node:zlib';

// Generates the placeholder product images the seed uploads to MinIO.
// Pure-Node PNG encoding (no image library): each product gets a couple of
// smooth two-tone gradients with a soft highlight, colored deterministically
// from its slug — so reseeding produces identical bytes.

const IMAGE_SIZE = 800;

function crc32(buffer: Buffer): number {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type: string, data: Buffer): Buffer {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const typeAndData = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(typeAndData));
  return Buffer.concat([length, typeAndData, crc]);
}

type PixelFn = (x: number, y: number) => [number, number, number];

function encodePng(size: number, pixel: PixelFn): Buffer {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0); // width
  ihdr.writeUInt32BE(size, 4); // height
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // color type: truecolor RGB

  // One filter byte (0 = None) prefixes every scanline.
  const raw = Buffer.alloc(size * (1 + size * 3));
  for (let y = 0; y < size; y++) {
    const row = y * (1 + size * 3);
    for (let x = 0; x < size; x++) {
      const [r, g, b] = pixel(x, y);
      const offset = row + 1 + x * 3;
      raw[offset] = r;
      raw[offset + 1] = g;
      raw[offset + 2] = b;
    }
  }

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function hslToRgb(h: number, s: number, l: number): [number, number, number] {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  const [r, g, b] =
    h < 60 ? [c, x, 0]
    : h < 120 ? [x, c, 0]
    : h < 180 ? [0, c, x]
    : h < 240 ? [0, x, c]
    : h < 300 ? [x, 0, c]
    : [c, 0, x];
  return [
    Math.round((r + m) * 255),
    Math.round((g + m) * 255),
    Math.round((b + m) * 255),
  ];
}

export function hueFromSlug(slug: string): number {
  let hash = 0;
  for (const char of slug) {
    hash = (hash * 31 + char.charCodeAt(0)) % 360;
  }
  return hash;
}

/**
 * A vertical gradient between two tones of the product's hue, with a soft
 * radial highlight — reads as deliberate art direction rather than a broken
 * image. `variant` rotates the hue so multi-image products don't repeat.
 */
export function productImagePng(slug: string, variant: number): Buffer {
  const hue = (hueFromSlug(slug) + variant * 32) % 360;
  const top = hslToRgb(hue, 0.45, 0.72);
  const bottom = hslToRgb((hue + 24) % 360, 0.5, 0.42);
  const highlightX = IMAGE_SIZE * 0.35;
  const highlightY = IMAGE_SIZE * 0.3;
  const highlightRadius = IMAGE_SIZE * 0.5;

  return encodePng(IMAGE_SIZE, (x, y) => {
    const t = y / (IMAGE_SIZE - 1);
    const distance = Math.hypot(x - highlightX, y - highlightY);
    const glow = Math.max(0, 1 - distance / highlightRadius) * 0.3;
    const blend = (from: number, to: number) => {
      const base = from + (to - from) * t;
      return Math.min(255, Math.round(base + (255 - base) * glow));
    };
    return [blend(top[0], bottom[0]), blend(top[1], bottom[1]), blend(top[2], bottom[2])];
  });
}
