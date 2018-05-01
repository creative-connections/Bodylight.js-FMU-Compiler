/**
 * Glue code injected into the Module, cwraps common fmi2Functions,
 * handles modelDescription.xml file parsing and more.
 *
 * This code is run trough a JS optimiser (uglify-js), which, at the time of
 * writing (2018) does not support some ES6 features, such as arrow functions.
 */

/**
 * Converts TypedArray to Uint8Array
 */
Module['heapArray'] = function (arr) {
  var numBytes = arr.length * arr.BYTES_PER_ELEMENT
  var ptr = this._malloc(numBytes)
  // heapBytes.byteOffset is the ptr
  var heapBytes = new Uint8Array(this.HEAPU8.buffer, ptr, numBytes)
  heapBytes.set(new Uint8Array(arr.buffer))
  return heapBytes
}

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
 * Parses FMU modelDescription.xml.
 */
Module['parseXML'] = function () {
  var resolver = this.xmlDoc.createNSResolver(
    this.xmlDoc.ownerDocument == null
      ? this.xmlDoc.documentElement
      : this.xmlDoc.ownerDocument.documentElement
  )

  // GUID is used for model identification
  this.guid = this.xmlDoc.evaluate(
    'string(//fmiModelDescription/@guid)',
    this.xmlDoc, resolver, XPathResult.STRING_TYPE, null).stringValue

  // identifier is prepended to names of FMI C functions
  this.identifier = this.xmlDoc.evaluate(
    'string(//fmiModelDescription/CoSimulation/@modelIdentifier)',
    this.xmlDoc, resolver, XPathResult.STRING_TYPE, null).stringValue

  // TODO: parse variables
  // TODO: parse parameters
}

/**
 * Cwraps all of the necessary C functions to be used by the module.
 */
Module['wrapFunctions'] = function () {
  this.snprintf = this.cwrap(
    'snprintf', 'number', [
      'number', 'number', 'number', 'number'
    ]
  )

  this.fmi2GetTypesPlatform = this.cwrap(
    this.identifier + '_fmi2GetTypesPlatform',
    'string'
  )

  this.fmi2GetVersion = this.cwrap(
    this.identifier + '_fmi2GetVersion',
    'string'
  )

  this.createFmi2CallbackFunctions = this.cwrap(
    'createFmi2CallbackFunctions', 'number', [
      'number'
    ]
  )

  this.fmi2Instantiate = this.cwrap(
    this.identifier + '_fmi2Instantiate', 'number', [
      'string',
      'number',
      'string',
      'string',
      'number',
      'number',
      'number'
    ]
  )

  this.fmi2SetupExperiment = this.cwrap(
    this.identifier + '_fmi2SetupExperiment', 'number', [
      'number',
      'number',
      'number',
      'number',
      'number',
      'number'
    ]
  )

  this.fmi2EnterInitializationMode = this.cwrap(
    this.identifier + '_fmi2EnterInitializationMode', 'number', [
      'number'
    ]
  )

  this.fmi2ExitInitializationMode = this.cwrap(
    this.identifier + '_fmi2ExitInitializationMode', 'number', [
      'number'
    ]
  )

  this.fmi2GetReal = this.cwrap(
    this.identifier + '_fmi2GetReal', 'number', [
      'number',
      'number',
      'number',
      'number'
    ]
  )

  this.fmi2SetReal = this.cwrap(
    this.identifier + '_fmi2SetReal', 'number', [
      'number',
      'number',
      'number',
      'number'
    ]
  )

  this.fmi2DoStep = this.cwrap(
    this.identifier + '_fmi2DoStep', 'number', [
      'number',
      'number',
      'number',
      'number'
    ]
  )
}

/**
 * Loads and parses modelDescription.xml, adds FMI C api to the model.
 */
Module['loadFmiFunctions'] = function () {
  var self = this
  return new Promise(function (resolve, reject) {
    self.loadXML().then(function (val) {
      self.parseXML()
      self.wrapFunctions()
      resolve(self)
    }).catch(function (err) {
      reject(err)
    })
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
    Module['loadFmiFunctions']().then(function (result) {
      resolve(Module)
    }).catch(function (err) {
      reject(err)
    })
  })
})
