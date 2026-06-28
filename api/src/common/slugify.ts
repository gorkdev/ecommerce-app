// URL-safe slug generator with Turkish character transliteration.
// "Spor Ayakkabı" -> "spor-ayakkabi"
const TR_MAP: Record<string, string> = {
  ç: 'c',
  ğ: 'g',
  ı: 'i',
  ö: 'o',
  ş: 's',
  ü: 'u',
  Ç: 'c',
  Ğ: 'g',
  İ: 'i',
  Ö: 'o',
  Ş: 's',
  Ü: 'u',
};

export function slugify(input: string): string {
  return input
    .split('')
    .map((char) => TR_MAP[char] ?? char)
    .join('')
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
