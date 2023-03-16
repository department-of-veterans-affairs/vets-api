const fs = require('fs');
const core = require('@actions/core');
const { exit } = require('process');
const yaml = require('js-yaml');


/* eslint-disable no-console */


const deleteFiles = valuesFiles => {
  core.exportVariable('FILES_TO_DELETE', true);
  const envFileContents = yaml.load(
    fs.readFileSync(
      './manifests/apps/preview-environment/dev/argocd-apps/values.yaml',
    ),
  );
  valuesFiles.forEach(file => {
    const envFileMatch = envFileContents.environments.filter(
      environment => environment.name === file.split('.')[0],
    );
    if (file !== 'template-values.yaml' && file !== 'Chart.yaml') {
      try {
        if (envFileMatch.length > 0) {
          core.exportVariable('ENVS_TO_DELETE', true);
          envFileMatch.forEach(match => {
            envFileContents.environments.splice(
              envFileContents.indexOf(match),
              1,
            );
            console.log(`${match} deleted from environment list`);
          });
        } else {
          core.exportVariable('ENVS_TO_DELETE', false);
        }
        fs.unlinkSync(
          `./manifests/apps/preview-environment/dev/pe-envs/${file}`,
        );
        console.log(`${file} values file removed`);
        const newEnvYaml = yaml.dump(envFileContents, {
          skipInvalid: true,
          lineWidth: -1,
          indent: 0,
        });
        fs.writeFileSync(
          './manifests/apps/preview-environment/dev/argocd-apps/values.yaml',
          newEnvYaml,
        );
      } catch (error) {
        console.log(error);
        exit(1);
      }
    }
  });
};

if (process.env.TRIGGERING_EVENT === 'delete') {
  const valuesFiles = fs
    .readdirSync('./manifests/apps/preview-environment/dev/pe-envs/')
    .filter(file =>
      file.includes(
        `${process.env.CURRENT_REPOSITORY}-${process.env.DELETED_BRANCH}`,
      ),
    );

  if (valuesFiles.length > 0) {
    deleteFiles(valuesFiles);
  } else {
    core.exportVariable('FILES_TO_DELETE', false);
    core.exportVariable('ENVS_TO_DELETE', false);
  }
}
