# Codespaces setup

## About codespaces

Github Codespaces provide an Integrated Development Environment (IDE) that is accessible entirely in a web browser. It is essentially a web based version of VS Code running on a cloud based virtual machine.

Codespaces is available for all members of the Department of Veterans Affairs organization on Github.

### More information

- [Platform documentation for codespaces](https://depo-platform-documentation.scrollhelp.site/developer-docs/using-github-codespaces)
- See the #codespaces channel in Slack for additional questions about using Codespaces.

## Creating a codespace

1. Go to [your Codespaces page](https://github.com/codespaces) on Github.
2. Click the [new Codespace](https://github.com/codespaces/new) button at the top right.
3. Select the vets-api repository and adjust other settings as desired, the defaults should work well.
4. Click the 'Create codespace' button

Your new codespace will open in Visual Studio Code if you have it installed locally, or otherwise in the browser. The vets-api repo and all dependencies will be installed, and it will be ready for use in about 5 minutes.

## Using your codespace

Your codespace will automatically start vets-api and forward port 3000 to your local machine if you have Visual Studio Code installed. The API can be accessed at http://localhost:3000/

For more information on running vets-api and specs, see the [native running instructions](running_natively.md).
