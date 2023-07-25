const cypress = require('cypress')

cypress.run({
  headless: true,
}).then(result => {
  if (result.status === 'failed') {
    process.exit(1);
  }
}).catch(err => {
  console.error("CAUGHT ERROR")
  console.error(err)
  process.exit(2)
})
