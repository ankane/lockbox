# Compatibility

Here’s how to decrypt in other languages. For files, skip Base64 decoding the ciphertext.

- [Node.js](#node-js)
- [Python](#python)
- [Rust](#rust)

Pull requests are welcome for other languages.

## Node.js

```js
const crypto = require('crypto')

let key = '61e6ba4a3a2498e3a8fdcd047eff0cd9864016f2c83c34599a3257a57ce6f7fb'
let ciphertext = 'Uv/+Sgar0kM216AvVlBH5Gt8vIwtQGfPysl539WY2DER62AoJg=='

key = Buffer.from(key, 'hex')
ciphertext = Buffer.from(ciphertext, 'base64') // skip for files

let nonce = ciphertext.slice(0, 12)
let auth_tag = ciphertext.slice(-16)
ciphertext = ciphertext.slice(12, -16)

let aesgcm = crypto.createDecipheriv('aes-256-gcm', key, nonce)
aesgcm.setAuthTag(auth_tag)
let plaintext = aesgcm.update(ciphertext) + aesgcm.final()
```

## Python

Install the [cryptography](https://cryptography.io/en/latest/) package and use:

```py
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from base64 import b64decode

key = '61e6ba4a3a2498e3a8fdcd047eff0cd9864016f2c83c34599a3257a57ce6f7fb'
ciphertext = 'Uv/+Sgar0kM216AvVlBH5Gt8vIwtQGfPysl539WY2DER62AoJg=='

key = bytes.fromhex(key)
ciphertext = b64decode(ciphertext) # skip for files

aesgcm = AESGCM(key)
plaintext = aesgcm.decrypt(ciphertext[:12], ciphertext[12:], b'')
```

## Rust

Add crates:

```toml
[dependencies]
aead = "0.2.0"
aes-gcm = "0.3.2"
base64 = "0.11.0"
hex = "0.4.2"
```

And use:

```rust
let key = hex::decode("61e6ba4a3a2498e3a8fdcd047eff0cd9864016f2c83c34599a3257a57ce6f7fb").expect("decode failure!");
let ciphertext = base64::decode("Uv/+Sgar0kM216AvVlBH5Gt8vIwtQGfPysl539WY2DER62AoJg==").expect("decode failure!");

use aes_gcm::Aes256Gcm;
use aead::{Aead, NewAead, generic_array::GenericArray};

let aead = Aes256Gcm::new(GenericArray::clone_from_slice(&key));
let nonce = GenericArray::from_slice(&ciphertext[..12]);
let plaintext = aead.decrypt(nonce, &ciphertext[12..]).expect("decryption failure!");
```

Check out the [aes-gcm docs](https://docs.rs/aes-gcm/) for more on security and performance.
