import figlet from "figlet";
import inquirer from "inquirer";

import { deploy } from "./deploy.js";

export default () => {
  intro();

  inquirer
    .prompt([
      {
        type: "list",
        name: "chainType",
        message: "Are you deploying on a testnet or mainnet?",
        choices: ["Testnet", "Mainnet"],
        filter(val) {
          return val.toLowerCase();
        },
      },
      {
        type: "checkbox",
        name: "chains",
        message: "Select the chains you want to deploy to:",
        choices: [
          {
            name: "Avalanche",
          },
          {
            name: "Arbitrum",
          },
          {
            name: "BNB Smart Chain",
          },
        ],
        validate(answer) {
          if (answer.length < 1) {
            return "You must choose at least one chain.";
          }

          return true;
        },
        filter(val: string[]) {
          return val.map((value) => value.toLowerCase().replace(/\s/g, "-"));
        },
      },
      {
        type: "string",
        name: "tokenName",
        message: "What should be the name of the token?",
      },
      {
        type: "string",
        name: "tokenSymbol",
        message: "What should be the symbol of the token?",
      },
      {
        type: "number",
        name: "floorPrice",
        message: "What should be the floor price of the token? (in USD)",
      },
      {
        type: "list",
        name: "pairBinStep",
        message: "Which bin step should have the LB pair?",
        choices: [25, 50, 100],
        default: 50,
      },
    ])
    .then((answers) => {
      deploy(answers);
    });
};

const intro = () => {
  console.log(
    "\n\n" +
      figlet.textSync("Floor Token", {
        font: "Basic",
        width: 120,
        whitespaceBreak: true,
      })
  );
};
