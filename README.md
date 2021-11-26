# WAGMI Submission - Ohmptions

Repo with option factory that can be used to create put / call options  

Google Doc Explainer : https://docs.google.com/presentation/d/1D7ZbgSSUrRY4DzEahYiFbxBon_iup-8LlsyenOWjQlY/edit?usp=sharing

Video Explainer : xxx

Main Contracts 

Option Factory (optionFactory.sol)
- This allows users to create call / put options with desired strike price + amount of collateral lock 
- creates contract following "OptionVaultSimple.sol" pattern -> this has collateral locked in escrow as needed if options are executed + can also allocated lock funds to a vault to earn yield
- mints buyerERC20.sol tokens (in derivatesPool.sol file) which are sold through sales contract (SaleContract.sol) holders of these tokens can exercise options
- by entering correct inputs DSLA's covering various risks can be created 
For example if bonds of Token X were being issued at $1000 / bond & the protocol wanted to provide users with the ability to hedge their lossess over the bonding period an option could be created allowing for one Token X to be sold for $900 each. This would mean that holders of these options retain upside potential if the price of TOken X increases while limiting their downside risk.   
- Additionally to solve the problem of capital efficiency the contract which holds these funds in Escrow can deploy them to a vault, 
- For the protocol providing these options this helps generate additional revenue through the selling of options (can be considered a form of insurance) while also giving users more confidence as a % of treasury is allocate to buying back tokens if the price drops.

Sales Contract (SaleContract.sol)
- Options create through the option factory are sold through here allowing users to purchase ERC20 tokens which give them the right to excercise options. The price options are sold at is specified in the option factory when creating the intial option and locking away the funds in escrow 

Example Script : https://github.com/DojimaFinance/Wagmi-Labs-Hackathon/blob/master/exampleScript.txt

Testnet Deployments : 
Option Factory (used to create options such as above put otions) : 
https://testnet.ftmscan.com/address/0x7517D47769156295622fb4bD5516f73b4569449D#code

