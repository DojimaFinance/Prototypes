# WAGMI Submission - Ohmptions

Repo with option factory that can be used to create put / call options  

Google Doc Explainer : https://docs.google.com/presentation/d/1D7ZbgSSUrRY4DzEahYiFbxBon_iup-8LlsyenOWjQlY/edit?usp=sharing

Main Contracts 

Option Factory (optionFactory.sol)
- This allows users to create call / put options with desired strike price + amount of collateral lock 
- creates contract following "OptionVaultSimple.sol" pattern -> this has collateral locked in escrow as needed if options are executed + can also allocated lock funds to a vault to earn yield
- mints buyerERC20.sol tokens (in derivatesPool.sol file) which are sold through sales contract (SaleContract.sol) holders of these tokens can exercise options relative to the amount they hold 
- by entering correct inputs DSLA's covering various risks can be created 
For example if bonds of Token X were being issued at $1000 / bond & the protocol wanted to provide users with the ability to hedge their lossess over the bonding period an option could be created allowing for one Token X to be sold for $900 each. This would mean that holders of these options retain upside potential if the price of TOken X increases while limiting their downside risk.   
- Additionally to solve the problem of capital efficiency the contract which holds these funds in Escrow can deploy them to a vault, 
- For the protocol providing these options this helps generate additional revenue through the selling of options (can be considered a form of insurance) while also giving users more confidence as a % of treasury is allocate to buying back tokens if the price drops.

Sales Contract (SaleContract.sol)
- Options create through the option factory are sold through here allowing users to purchase ERC20 tokens which give them the right to excercise options. The price options are sold at is specified in the option factory when creating the intial option and locking away the funds in escrow 

Example Script for Put Options (allow option holders to sell back OHM to treasury / at some discount vs bonding price acts as insurnace if there is bank run): https://github.com/DojimaFinance/Wagmi-Labs-Hackathon/blob/master/putOption.txt

Example Script for Call Options (user can purchase options to buy OHM at bond price up to expiry of bond) 
: https://github.com/DojimaFinance/Wagmi-Labs-Hackathon/blob/master/callOption.txt

Additional Contracts include 
lendFactory.sol & lendFactoryNFT.sol which allow users to offer some collateral & terms for a loan i.e. asset to borrow & repayment timeline. The lending contracts used act as p2p loans with similiar mechanics to mortgages.

Testnet Deployments (from previous iteration won't 100% align with current repo) : 

Sale contract : https://testnet.ftmscan.com/address/0x76a84ff11af41ba1cbe0c738e21731835bf38f9b#code

Option Factory : 
https://testnet.ftmscan.com/address/0x7517D47769156295622fb4bD5516f73b4569449D#code

Loan Factory : 
https://testnet.ftmscan.com/address/0xafd9979E839ca365df18EA31a02ef4060cB39914#code


