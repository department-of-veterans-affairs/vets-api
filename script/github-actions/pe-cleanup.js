const fs = require('fs');
const core = require('@actions/core');
const { exit } = require('process');

/* eslint-disable no-console */


const deleteFiles = valuesFiles => {
  core.exportVariable('FILES_TO_DELETE', true);
  valuesFiles.forEach(file => {
    try {
      fs.unlinkSync(
        `./manifests/apps/preview-environment/dev/environment-values/${file}`,
      );
      console.log(`${file} removed`);
    } catch (error) {
      console.log(error);
      exit(1);
    }
  });
};

if (process.env.TRIGGERING_EVENT === 'delete') {
  const valuesFiles = fs
    .readdirSync('./manifests/apps/preview-environment/dev/environment-values/')
    .filter(file =>
      file.includes(
        `${process.env.CURRENT_REPOSITORY}-${process.env.DELETED_BRANCH}`,
      ),
    );

  if (valuesFiles.length > 0) {
    deleteFiles(valuesFiles);
  } else {
    core.exportVariable('FILES_TO_DELETE', false);
  }
}
