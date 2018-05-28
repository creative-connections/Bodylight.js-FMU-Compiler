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
 * Sets Reals to FMU
 */
Module['setReal'] = function (query, value, count) {
  return this.fmi2SetReal(this.inst, query.byteOffset, count, value.byteOffset)
}

/**
 * Sets Booleans to FMU
 */
Module['setBoolean'] = function (query, value, count) {
  return this.fmi2SetBoolean(this.inst, query.byteOffset, count, value.byteOffset)
}

/**
 * Loads Reals from FMU
 */
Module['getReal'] = function (query, output, count) {
  return this.fmi2GetReal(this.inst, query.byteOffset, count, output.byteOffset)
}

/**
 * Loads Booleans from FMU
 */
Module['getBoolean'] = function (query, output, count) {
  return this.fmi2GetBoolean(this.inst, query.byteOffset, count, output.byteOffset)
}

/**
 * Sets every value waiting in the setQueues
 */
Module['flushSetQueues'] = function () {
  this.flushRealQueue()
  this.flushBooleanQueue()
}

Module['flushBooleanQueue'] = function () {
  if (this.setBooleanQueue) {
    var references = this.heapArray(new Int32Array(this.setBooleanQueue.references))
    var values = this.heapArray(new Int32Array(this.setBooleanQueue.values))

    this.setBoolean(references, values, this.setBooleanQueue.references.length)
    this._free(references.byteOffset)
    this._free(values.byteOffset)

    this.setBooleanQueue = false
  }
}

Module['flushRealQueue'] = function () {
  if (this.setRealQueue) {
    var references = this.heapArray(new Int32Array(this.setRealQueue.references))
    var values = this.heapArray(new Float64Array(this.setRealQueue.values))

    this.setReal(references, values, this.setRealQueue.references.length)
    this._free(references.byteOffset)
    this._free(values.byteOffset)

    this.setRealQueue = false
  }
}

/**
 * Adds a real value to setRealQueue
 */
Module['setSingleReal'] = function (reference, value) {
  if (!this.setRealQueue) {
    this.setRealQueue = {
      references: [],
      values: []
    }
  }
  this.setRealQueue.references.push(reference)
  this.setRealQueue.values.push(value)
}

/**
 * Loads a single real value based on reference, this is a shorthand function.
 * It is recommended to use Module.getReal with reusable mallocs.
 */
Module['getSingleReal'] = function (reference) {
  var query = this.heapArray(new Int32Array([reference]))
  var output = this.heapArray(new Float64Array(1))
  this.getReal(query, output, 1)
  var num = new Float64Array(output.buffer, output.byteOffset, 1)
  this._free(query.byteOffset)
  this._free(output.byteOffset)
  return num[0]
}

/**
 */
Module['setSingleBoolean'] = function (reference, value) {
  if (!this.setBooleanQueue) {
    this.setBooleanQueue = {
      references: [],
      values: []
    }
  }
  this.setBooleanQueue.references.push(reference)
  this.setBooleanQueue.values.push(value)
}

/**
 * Loads a single boolean value based on reference, this is a shorthand function.
 * It is recommended to use Module.getBoolean with reusable mallocs.
 */
Module['getSingleBoolean'] = function (reference) {
  var query = this.heapArray(new Int32Array([reference]))
  var output = this.heapArray(new Int32Array(1))
  this.getBoolean(query, output, 1)
  var num = new Int32Array(output.buffer, output.byteOffset, 1)
  this._free(query.byteOffset)
  this._free(output.byteOffset)
  return num[0]
}

/**
 * Loads Reals from FMU based on Module.config.variables
 */
Module['getRealFromConfig'] = function () {
  return this.fmi2GetReal(
    this.inst,
    this.config.variables.byteOffset,
    this.config.count,
    this.config.output.byteOffset)
}

/**
 * Implements a rudimentary browser console logger for the FMU.
 */
Module['consoleLogger'] = function (
  componentEnvironment, instanceName, status, category, message, other) {
  /* Fills variables into message returned by the FMU, the C way */
  var formatMessage = function (message, other) {
    // get a new pointer
    var ptr = Module._malloc(1)
    // get the size of the resulting formated message
    var num = Module.snprintf(ptr, 0, message, other)
    Module._free(ptr)
    num++ // TODO: Error handling num < 0
    ptr = Module._malloc(num)
    Module.snprintf(ptr, num, message, other)

    // return pointer to the resulting message string
    return ptr
  }

  console.log('FMU(' + Module.UTF8ToString(instanceName) +
    ':' + status + ':' +
    Module.UTF8ToString(category) +
    ') msg: ' + Module.UTF8ToString(formatMessage(message, other))
  )

  Module._free(formatMessage)
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
}

/**
 * Parses FMU variables from modelDescription.xml
 */
Module['parseFmuVariables'] = function () {
  this.fmuVariables = {}

  var resolver = this.xmlDoc.createNSResolver(
    this.xmlDoc.ownerDocument == null
      ? this.xmlDoc.documentElement
      : this.xmlDoc.ownerDocument.documentElement
  )
  var variableIterator = this.xmlDoc.evaluate(
    '//ScalarVariable[not(@causality="parameter")]',
    this.xmlDoc,
    resolver,
    XPathResult.UNORDERED_NODE_ITERATOR_TYPE,
    null
  )

  try {
    var node = variableIterator.iterateNext()
    while (node) {
      var name = node.getAttribute('name')
      this.fmuVariables[name] = {
        'name': node.getAttribute('name'),
        'reference': node.getAttribute('valueReference'),
        'description': node.getAttribute('description'),
        'causality': node.getAttribute('causality'),
        'variability': node.getAttribute('variability'),
        'initial': node.getAttribute('initial'),
        'canHandleMultipleSetPerTimeInstant':
          node.getAttribute('canHandleMultipleSetPerTimeInstant')
      }
      node = variableIterator.iterateNext()
    }
  } catch (e) {
    console.error('Error while parsing FMU variables: ' + e)
  }
}

/**
 * Parses FMU parameters from modelDescription.xml
 */
Module['parseFmuParameters'] = function () {
  this.fmuParameters = {}

  var resolver = this.xmlDoc.createNSResolver(
    this.xmlDoc.ownerDocument == null
      ? this.xmlDoc.documentElement
      : this.xmlDoc.ownerDocument.documentElement
  )
  var parmIterator = this.xmlDoc.evaluate(
    '//ScalarVariable[@causality="parameter"]',
    this.xmlDoc,
    resolver,
    XPathResult.UNORDERED_NODE_ITERATOR_TYPE,
    null
  )
  try {
    var node = parmIterator.iterateNext()
    while (node) {
      var name = node.getAttribute('name')
      this.fmuParameters[name] = {
        'name': node.getAttribute('name'),
        'reference': node.getAttribute('valueReference'),
        'description': node.getAttribute('description'),
        'causality': node.getAttribute('causality'),
        'variability': node.getAttribute('variability'),
        'initial': node.getAttribute('initial'),
        'canHandleMultipleSetPerTimeInstant':
          node.getAttribute('canHandleMultipleSetPerTimeInstant')
      }
      node = parmIterator.iterateNext()
    }
  } catch (err) {
    console.error('Error while parsing FMU parameters: ' + err)
  }
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

  this.fmi2GetBoolean = this.cwrap(
    this.identifier + '_fmi2GetBoolean', 'number', [
      'number',
      'number',
      'number',
      'number'
    ]
  )

  this.fmi2SetBoolean = this.cwrap(
    this.identifier + '_fmi2SetBoolean', 'number', [
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
 * Adds useful function pointers to the heap
 */
Module['addFunctionPointers'] = function () {
  // rudimentary console logger
  this.consoleLoggerPtr = this.addFunction(this.consoleLogger)
}

/**
 * Defines enum values.
 */
Module['addEnumValues'] = function () {
  this.fmi2CoSimulation = 1
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
      self.addFunctionPointers()
      self.addEnumValues()
      self.parseFmuParameters()
      self.parseFmuVariables()

      resolve(self)
    }).catch(function (err) {
      reject(err)
    })
  })
}

/* Boolean defines */
Module['fmi2True'] = 1
Module['fmi2False'] = 0

Module['setRealQueue'] = false
Module['setBooleanQueue'] = false

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
