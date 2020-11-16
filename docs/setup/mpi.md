## MPI Service

The Master Person Index (formerly Master Veteran Index, so mvi is used as a key for settings purposes) service retrieves and updates a veteran's 'golden
record'. To configure `vets-api` for use with MPI, configure
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
