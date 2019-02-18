# komodo-coda-ac

## What is Coda?

Coda is a new cryptocurrency protocol with a lightweight, constant sized blockchain.

Please see Coda's [developer README](README-dev.md) if you are interested in building coda from source code.

## How to build Coda?

### Useful info

* [Coda homepage](https://codaprotocol.com/)
* [Roadmap](https://github.com/orgs/CodaProtocol/projects/1)
* [Developer homepage](https://codaprotocol.com/code.html)
* [Developer readme](README-dev.md)
* [Compiling from source and and running a node](docs/demo.md)


## Coda clis

You can check the clis of the Coda with the below instruction.

```pycon
coda client help
```

## Clis for the burn protocol

* How to run the coda daemons

You need to run seed, proposer and snarker daemons to run the coda.
Follow the instructions from the coda help to install the environment and run the coda daemons.
Here are some example instructions to run the daemons.

Starting seed on port 8301
```
coda.exe daemon   -txn-capacity 8 -ip 127.0.0.1 -client-port 8301 -external-port 8302 -rest-port 8310 -config-directory /home/ryan/codademo/conf-8300 > log-8300.txt &
```

Staring proposer on port 8401
```
coda.exe daemon -propose-key ./funded_wallet/key -peer 127.0.0.1:8303  -txn-capacity 8 -ip 127.0.0.1 -client-port 8401 -external-port 8402 -rest-port 8410 -config-directory /home/ryan/codademo/conf-8400 > log-8400.txt &
```

Staring snarker on port 8501
```
coda.exe daemon -run-snark-worker KNQxdQ2zGPN+xbEinl9//vVvVxIvI/I6UCXiYCj3Bu66afuhDHkBAAAA -peer 127.0.0.1:8303  -txn-capacity 8 -ip 127.0.0.1 -client-port 8501 -external-port 8502 -rest-port 8510 -config-directory /home/ryan/codademo/conf-8500 > log-8500.txt &
```

* Burn Cli

You can check the parameters for this cli with the below instruction.
```
coda client burn -h
```
This instruction will return the receipt chain hash as the result. You can check the validation of this tx with the receipt chain hash.
```
coda client prove-payment
```
This instruction will check if the tx is validated or not. The tx will include the amount, the public address of coda wallet and the komodo address.
It will return the array of the tx if the validation is successful.
It will return error if the tx is not validated yet.

* Opposite burn cli.

There is a cli to add fund of the coda wallet according to the komodo side burn.
```
coda client add-fund
```
You can also check this tx's validation using the prove-payment cli.


### Learn more
*  [Directory structure](DIRECTORY_STRUCTURE.md)
*  [Lifecycle of a payment](docs/lifecycle_of_a_payment_lite.md)