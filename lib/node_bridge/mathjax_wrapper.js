var mjAPI = require('mathjax-node')

mjAPI.config({
  MathJax: {
    // traditional MathJax configuration
  },
})

mjAPI.start()

module.exports = {
  typeset: function (options) {
    return new Promise((resolve, reject) => {
      mjAPI.typeset(options, function (data) {
        if (data.errors && data.errors.length > 0) {
          reject(data.errors)
        } else {
          resolve(data)
        }
      })
    })
  },
}
