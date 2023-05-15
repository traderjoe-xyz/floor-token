import axios from "axios";

export const getCoingeckoPrices = async () => {
  try {
    const response = await axios.get(
      "https://api.coingecko.com/api/v3/simple/price",
      {
        params: {
          ids: "ethereum,avalanche-2,binancecoin",
          vs_currencies: "usd",
        },
      }
    );
    return response.data;
  } catch (error) {
    console.error(error);
  }
};
