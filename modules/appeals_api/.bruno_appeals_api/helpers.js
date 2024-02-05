const uuid = require('uuid')
const axios = require('axios')

function getEnvVar (varName) {
  const value = bru.getEnvVar(varName)
  if (!value) {
    throw new Error(`Couldn't find a value for the variable '${varName}' in the current Bruno environment - please set it and try this request again.`)
  }
  return value
}

function getVar (varName) {
  const value = bru.getVar(varName)
  if (!value) {
    throw new Error(`Couldn't find a value for the variable '${varName}' in the current Bruno request settings - please set it and try this request again.`)
  }
  return value
}

async function generateToken () {
  const tokenUrl = getEnvVar('oauth_token_url')
  const aud = getEnvVar('oauth_audience')
  const clientId = getEnvVar('oauth_client_id')
  const privatePem = getEnvVar('oauth_private_pem')
  const scope = getVar('oauth_scope')

  const secondsSinceEpoch = Math.round(Date.now() / 1000)
  const headers = { alg: 'RS256', typ: 'JWT' }
  const payload = {
    aud,
    iss: clientId,
    sub: clientId,
    iat: secondsSinceEpoch,
    exp: secondsSinceEpoch + 60,
    jti: uuid.v4()
  }

  let rsaSign

  try {
    rsaSign = require('jsrsasign')
  } catch (e) {
    throw new Error(`Couldn't load jsrasign library; Please run 'npm install' in ${__dirname} and try again.`)
  }

  const jwt = rsaSign.jws.JWS.sign(null, headers, payload, privatePem)

  try {
    const res = await axios.post(
      tokenUrl,
      {
        grant_type: 'client_credentials',
        client_assertion: jwt,
        client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
        scope
      },
      {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      }
    )
    return res.data.access_token
  } catch (e) {
    if (e.response) {
      console.error(
        `Received ${e.response.status} error from ${tokenUrl}. Body:\n${JSON.stringify(e.response.data, null, 2)}`
      )
    }

    throw `Got ${e.response.status} error while fetching a token. See developer console for details.`
  }
}

// Call this method in a Pre Request script to fill the {{bearer_token}} variable with a CCG token. Example:
//
// const { setOauthToken } = require('./helpers.js');
// await setOauthToken();
//
async function setOauthToken () {
  bru.setVar('bearer_token', await generateToken())
}

module.exports = {
  setOauthToken,
  generateToken
}
