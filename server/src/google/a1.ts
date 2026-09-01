/** 0始まりの列インデックスを A1記法の列文字（A, B, ..., Z, AA, ...）に変換する。 */
export function columnLetter(index0Based: number): string {
  let index = index0Based + 1;
  let letters = '';
  while (index > 0) {
    const remainder = (index - 1) % 26;
    letters = String.fromCharCode(65 + remainder) + letters;
    index = Math.floor((index - 1) / 26);
  }
  return letters;
}
