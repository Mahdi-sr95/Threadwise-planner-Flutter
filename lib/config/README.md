# Configuration Setup

## Secrets Management

This project uses a local `secrets.dart` file to store API tokens securely.

### First Time Setup

1. Copy the template file:
   ```bash
   cp lib/config/secrets.dart.example lib/config/secrets.dart
Edit lib/config/secrets.dart and replace placeholders with your actual tokens:

Get your Hugging Face token from: https://huggingface.co/settings/tokens

The secrets.dart file is already in .gitignore and will not be committed.

For Team Members
When cloning this repository, you must create your own secrets.dart file:

cd lib/config
cp secrets.dart.example secrets.dart
# Edit secrets.dart with your own tokens
Security Notes
Never commit secrets.dart to version control

Never share your tokens in chat, email, or screenshots

If a token is accidentally exposed, revoke it immediately and generate a new one

