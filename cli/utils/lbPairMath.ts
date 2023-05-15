export const getFloorBinId = (
  floorPriceUSD: number,
  nativePriceUSD,
  binStep: number
): number => {
  const floorPriceNative = getTokenPriceInNative(floorPriceUSD, nativePriceUSD);
  return getIdFromPrice(floorPriceNative, binStep);
};

export const getIdFromPrice = (price: number, binStep: number): number => {
  return Math.trunc(Math.log(price) / Math.log(1 + binStep / 10_000)) + 8388608;
};

export const getTokenPriceInNative = (
  tokenPriceUSD: number,
  nativePriceUSD: number
): number => {
  return tokenPriceUSD / nativePriceUSD;
};
