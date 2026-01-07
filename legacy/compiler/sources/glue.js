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
