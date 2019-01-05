# Compatibility

Here’s how to decrypt files in other languages.

## Python

Install the [cryptography](https://cryptography.io/en/latest/) package and do:

```py
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

key = bytes.fromhex('hex-key')
aesgcm = AESGCM(key)

ciphertext = open('file.txt.enc', 'rb').read()
plaintext = aesgcm.decrypt(ciphertext[:12], ciphertext[12:], b'')
```

## Other

Submit a PR
