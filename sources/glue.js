/**
 * Glue code injected into the Module, cwraps common fmi2Functions,
 * handles modelDescription.xml file parsing and more.
 *
 * This code is run trough a JS optimiser (uglify-js), which, at the time of
 * writing (2018) does not support some ES6 features, such as arrow functions.
 */

/**
 * Sends a XHR request to url Module.modelDescriptionFile,
 * expecting to find a FMU 2.0 modelDescription.xml file.
 * @return {Promise} rejects on not found
 */
Module['loadXML'] = function () {
  var self = this // thank you uglify-js for not supporting arrow functions
  return new Promise(function (resolve, reject) {
    if (typeof self.modelDescriptionFile === 'undefined') {
      reject(new Error('404 Parameter modelDescriptionFile is missing'))
    }

    var request = new XMLHttpRequest()
    request.open('GET', self.modelDescriptionFile, true)

    request.onload = function () {
      if (request.status === 200 || request.status === 203) {
        self.xmlDoc = request.responseXML
        resolve()
      } else {
        reject(new Error(request.status + ' ' + request.statusText))
      }
    }

    request.onerror = function () {
      reject(new Error(request.status + ' ' + request.statusText))
    }

    request.send(null)
  })
}

/**
* There is a bug in emscripten which causes Module.then to enter an
* infinite loop when called from Promise.all(), this is a workaround.
* Provides Module.ready Promise which is properly thennable.
*
* see: https://github.com/kripken/emscripten/issues/5820
* TODO: revisit when 5820 is resolved
*/
Module['ready'] = new Promise(function (resolve, reject) {
  delete Module['then']
  Module['onAbort'] = function (what) {
    reject(what)
  }
  addOnPostRun(function () {
    resolve(Module)
  })
})

Module['loadFmiFunctions'] = function () {
  var self = this
  return new Promise(function (resolve, reject) {
    self.loadXML().then(function (val) {
      resolve(self)
    }).catch(function (err) {
      reject(err)
    })
  })
}
