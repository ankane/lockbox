# Compatibility

Here’s how to decrypt in other languages. For files, skip Base64 decoding the ciphertext.

- [Node.js](#node-js)
- [Python](#python)
- [Rust](#rust)
- [Elixir](#elixir)
- [PHP](#php)
- [Java](#java)

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
aes-gcm = "0.10.3"
base64 = "0.22.1"
hex = "0.4.3"
```

And use:

```rust
use aes_gcm::aead::{generic_array::GenericArray, Aead};
use aes_gcm::{Aes256Gcm, Key, KeyInit};
use base64::prelude::*;

fn main() {
    let key = hex::decode("61e6ba4a3a2498e3a8fdcd047eff0cd9864016f2c83c34599a3257a57ce6f7fb").expect("decode failure!");
    let ciphertext = BASE64_STANDARD.decode("Uv/+Sgar0kM216AvVlBH5Gt8vIwtQGfPysl539WY2DER62AoJg==").expect("decode failure!");

    let key = Key::<Aes256Gcm>::from_slice(&key);
    let aead = Aes256Gcm::new(&key);
    let nonce = GenericArray::from_slice(&ciphertext[..12]);
    let plaintext = aead.decrypt(nonce, &ciphertext[12..]).expect("decryption failure!");
    println!("{:?}", String::from_utf8(plaintext).unwrap());
}
```

Check out the [aes-gcm docs](https://docs.rs/aes-gcm/) for more on security and performance.

## Elixir

```ex
{:ok, key} = Base.decode16("61e6ba4a3a2498e3a8fdcd047eff0cd9864016f2c83c34599a3257a57ce6f7fb", case: :lower)
{:ok, ciphertext} = Base.decode64("Uv/+Sgar0kM216AvVlBH5Gt8vIwtQGfPysl539WY2DER62AoJg==")

ciphertext_size = byte_size(ciphertext) - 28

<<nonce::binary-size(12), ciphertext::binary-size(ciphertext_size), tag::binary>> = ciphertext

:crypto.block_decrypt(:aes_gcm, key, nonce, {"", ciphertext, tag})
```

## PHP

```php
$key = "61e6ba4a3a2498e3a8fdcd047eff0cd9864016f2c83c34599a3257a57ce6f7fb";
$ciphertext = "Uv/+Sgar0kM216AvVlBH5Gt8vIwtQGfPysl539WY2DER62AoJg==";

$key = hex2bin($key);
$ciphertext = base64_decode($ciphertext, true);

$nonce = substr($ciphertext, 0, 12);
$tag = substr($ciphertext, -16);
$ciphertext = substr($ciphertext, 12, -16);

$plaintext = openssl_decrypt($ciphertext, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $nonce, $tag);
```

## Java

```java
import java.util.Base64;
import java.util.HexFormat;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

public class Example
{
    public static void main(String[] args) throws Exception {
        String key = "61e6ba4a3a2498e3a8fdcd047eff0cd9864016f2c83c34599a3257a57ce6f7fb";
        String ciphertext = "Uv/+Sgar0kM216AvVlBH5Gt8vIwtQGfPysl539WY2DER62AoJg==";

        byte[] keyBytes = HexFormat.of().parseHex(key);
        byte[] ciphertextBytes = Base64.getDecoder().decode(ciphertext);

        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(keyBytes, "AES"), new GCMParameterSpec(128, ciphertextBytes, 0, 12));
        String plaintext = new String(cipher.doFinal(ciphertextBytes, 12, ciphertextBytes.length - 12));
    }
}
```
