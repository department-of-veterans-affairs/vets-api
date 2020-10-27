## MVI Service

The Master Veteran Index service retrieves and updates a veteran's 'golden
record'. To configure `vets-api` for use with MVI, configure
`config/settings.local.yml` with the settings given to you by devops or your
team. For example,

```
# config/settings.local.yml
mvi:
  url: ...
```

Since that URL is only accessible over the VA VPN a mock service is included in
the project. To enable it, add this to `config/settings.local.yml`:

```
mvi:
  mock: true
```
