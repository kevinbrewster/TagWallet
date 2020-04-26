# TagWallet

TagWallet is an simple iOS app to manage MiFare NTAG215 NFC (e.g. Amiibo) tags. You can read tags, save the data dumps, 
and optionally write those data dumps to a new blank tag.

It's similar to the Android [TagMo](https://github.com/HiddenRamblings/TagMo) App.

## Requirements

iPhone 7 or above and iOS 13 or above (for NFC write capabilities)

## Installation

There is no binary available and the app is not available on the App Store. You need to download the code, 
open in XCode and manually run it on an iPhone. 

## Configuration

In the TagWalletUI folder is a file `tagWallet.json`. By default, this file is misconfigured. You will need 
to update the file with valid values to enable decrpytion and cloning of certain NTAG215 cards. 

`staticKey`: An 80-byte base64 encoded retail key (aka "locked-secret.bin")
`dataKey`: An 80-byte base64 encoded retail key (aka "unfixed-info.bin")

`tagWallet.json`

```json
{
  "dataKey": {
    "data": "__SOME_BASE64_ENCODED_STRING_OF_80_BYTES__"
  },
  "staticKey": {
    "data": "__SOME_BASE64_ENCODED_STRING_OF_80_BYTES__"
  },
  "tagProducts": [
    {
      "tail": "__4_BYTE_HEX__",
      "character": "Test",
      "head": "__4_BYTE_HEX__",
      "gameSeries": "Test",
      "type": "Figure",
      "imageURL": "",
      "name": "Test",
      "productSeries": "Test",
      "dumps": [
        {
          "data": "__SOME_BASE64_ENCODED_STRING_OF_540_BYTES__"
        }
      ]
    }
  ]
}
```




