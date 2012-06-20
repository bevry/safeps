// Generated by CoffeeScript 1.3.3
(function() {
  var balUtilFlow, balUtilPaths, fsUtil, pathUtil, _ref, _ref1, _ref2,
    __slice = [].slice,
    __hasProp = {}.hasOwnProperty;

  fsUtil = require('fs');

  pathUtil = require('path');

  balUtilFlow = require(__dirname + '/flow');

  balUtilPaths = null;

  if ((_ref = global.numberOfOpenFiles) == null) {
    global.numberOfOpenFiles = 0;
  }

  if ((_ref1 = global.maxNumberOfOpenFiles) == null) {
    global.maxNumberOfOpenFiles = 100;
  }

  if ((_ref2 = global.waitingToOpenFileDelay) == null) {
    global.waitingToOpenFileDelay = 100;
  }

  balUtilPaths = {
    openFile: function(next) {
      if (global.numberOfOpenFiles < 0) {
        throw new Error("balUtilPaths.openFile: the numberOfOpenFiles is [" + global.numberOfOpenFiles + "] which should be impossible...");
      }
      if (global.numberOfOpenFiles >= global.maxNumberOfOpenFiles) {
        setTimeout(function() {
          return balUtilPaths.openFile(next);
        }, global.waitingToOpenFileDelay);
      } else {
        ++global.numberOfOpenFiles;
        next();
      }
      return this;
    },
    closeFile: function(next) {
      --global.numberOfOpenFiles;
      if (typeof next === "function") {
        next();
      }
      return this;
    },
    readFile: function(path, encoding, next) {
      if (next == null) {
        next = encoding;
        encoding = null;
      }
      balUtilPaths.openFile(function() {
        return fsUtil.readFile(path, encoding, function(err, data) {
          balUtilPaths.closeFile();
          return next(err, data);
        });
      });
      return this;
    },
    writeFile: function(path, data, encoding, next) {
      if (next == null) {
        next = encoding;
        encoding = null;
      }
      balUtilPaths.ensurePath(pathUtil.dirname(path), function(err) {
        if (err) {
          return next(err);
        }
        return balUtilPaths.openFile(function() {
          return fsUtil.writeFile(path, data, encoding, function(err) {
            balUtilPaths.closeFile();
            return next(err);
          });
        });
      });
      return this;
    },
    mkdir: function(path, mode, next) {
      if (next == null) {
        next = mode;
        mode = null;
      }
      balUtilPaths.openFile(function() {
        return fsUtil.mkdir(path, mode, function(err) {
          balUtilPaths.closeFile();
          return next(err);
        });
      });
      return this;
    },
    stat: function(path, next) {
      balUtilPaths.openFile(function() {
        return fsUtil.stat(path, function(err, stat) {
          balUtilPaths.closeFile();
          return next(err, stat);
        });
      });
      return this;
    },
    readdir: function(path, next) {
      balUtilPaths.openFile(function() {
        return fsUtil.readdir(path, function(err, files) {
          balUtilPaths.closeFile();
          return next(err, files);
        });
      });
      return this;
    },
    unlink: function(path, next) {
      balUtilPaths.openFile(function() {
        return fsUtil.unlink(path, function(err) {
          balUtilPaths.closeFile();
          return next(err);
        });
      });
      return this;
    },
    rmdir: function(path, next) {
      balUtilPaths.openFile(function() {
        return fsUtil.rmdir(path, function(err) {
          balUtilPaths.closeFile();
          return next(err);
        });
      });
      return this;
    },
    exists: function(path, next) {
      var exists;
      exists = fsUtil.exists || pathUtil.exists;
      balUtilPaths.openFile(function() {
        return exists(path, function(exists) {
          balUtilPaths.closeFile();
          return next(exists);
        });
      });
      return this;
    },
    existsSync: function(path) {
      var existsSync, result;
      existsSync = fsUtil.existsSync || pathUtil.existsSync;
      result = existsSync(path);
      return result;
    },
    cp: function(src, dst, next) {
      balUtilPaths.readFile(src, 'binary', function(err, data) {
        if (err) {
          console.log("balUtilPaths.cp: cp failed on: " + src);
          return next(err);
        }
        return balUtilPaths.writeFile(dst, data, 'binary', function(err) {
          if (err) {
            console.log("balUtilPaths.cp: writeFile failed on: " + dst);
          }
          return next(err);
        });
      });
      return this;
    },
    getParentPathSync: function(p) {
      var parentPath;
      parentPath = p.replace(/[\/\\][^\/\\]+$/, '');
      return parentPath;
    },
    ensurePath: function(path, next) {
      path = path.replace(/[\/\\]$/, '');
      balUtilPaths.exists(path, function(exists) {
        var parentPath;
        if (exists) {
          return next();
        }
        parentPath = balUtilPaths.getParentPathSync(path);
        return balUtilPaths.ensurePath(parentPath, function(err) {
          if (err) {
            console.log("balUtilPaths.ensurePath: failed to ensure the path: " + parentPath);
            return next(err);
          }
          return balUtilPaths.mkdir(path, '700', function(err) {
            return balUtilPaths.exists(path, function(exists) {
              if (!exists) {
                console.log("balUtilPaths.ensurePath: failed to create the directory: " + path);
                return next(new Error("Failed to create the directory: " + path));
              }
              return next();
            });
          });
        });
      });
      return this;
    },
    prefixPathSync: function(path, parentPath) {
      path = path.replace(/[\/\\]$/, '');
      if (/^([a-zA-Z]\:|\/)/.test(path) === false) {
        path = pathUtil.join(parentPath, path);
      }
      return path;
    },
    isDirectory: function(path, next) {
      balUtilPaths.stat(path, function(err, stat) {
        if (err) {
          console.log("balUtilPaths.isDirectory: stat failed on: " + path);
          return next(err);
        }
        return next(null, stat.isDirectory(), stat);
      });
      return this;
    },
    generateSlugSync: function(path) {
      var result;
      result = path.replace(/[^a-zA-Z0-9]/g, '-').replace(/^-/, '').replace(/-+/, '-');
      return result;
    },
    scantree: function(path, next) {
      balUtilPaths.scandir({
        path: path,
        readFiles: true,
        ignoreHiddenFiles: true,
        next: function(err, list, tree) {
          return next(err, tree);
        }
      });
      return this;
    },
    commonIgnorePatterns: /^(\~|(\.(svn|git|hg|DS_Store))|node_modules|CVS|thumbs\.db|desktop\.ini)$/i,
    scandir: function() {
      var args, err, list, options, tasks, tree, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      list = {};
      tree = {};
      if (args.length === 1) {
        options = args[0];
      } else if (args.length >= 4) {
        options = {
          path: args[0],
          fileAction: args[1] || null,
          dirAction: args[2] || null,
          next: args[3] || null
        };
      } else {
        err = new Error('balUtilPaths.scandir: unsupported arguments');
        if (next) {
          return next(err);
        } else {
          throw err;
        }
      }
      if ((_ref3 = options.recurse) == null) {
        options.recurse = true;
      }
      if ((_ref4 = options.readFiles) == null) {
        options.readFiles = false;
      }
      if ((_ref5 = options.ignoreHiddenFiles) == null) {
        options.ignoreHiddenFiles = false;
      }
      if ((_ref6 = options.ignorePatterns) == null) {
        options.ignorePatterns = false;
      }
      if (options.action != null) {
        if ((_ref7 = options.fileAction) == null) {
          options.fileAction = options.action;
        }
        if ((_ref8 = options.dirAction) == null) {
          options.dirAction = options.action;
        }
      }
      if (options.ignorePatterns === true) {
        options.ignorePatterns = balUtilPaths.commonIgnorePatterns;
      }
      if (options.parentPath && !options.path) {
        options.path = options.parentPath;
      }
      if (!options.path) {
        err = new Error('balUtilPaths.scandir: path is needed');
        if (next) {
          return next(err);
        } else {
          throw err;
        }
      }
      tasks = new balUtilFlow.Group(function(err) {
        return options.next(err, list, tree);
      });
      balUtilPaths.readdir(options.path, function(err, files) {
        if (tasks.exited) {
          return;
        } else if (err) {
          debugger;
          console.log('balUtilPaths.scandir: readdir has failed on:', options.path);
          return tasks.exit(err);
        }
        tasks.total += files.length;
        if (!files.length) {
          return tasks.exit();
        } else {
          return files.forEach(function(file) {
            var fileFullPath, fileRelativePath, isHiddenFile, isIgnoredFile;
            isHiddenFile = options.ignoreHiddenFiles && /^\./.test(file);
            isIgnoredFile = options.ignorePatterns && options.ignorePatterns.test(file);
            if (isHiddenFile || isIgnoredFile) {
              return tasks.complete();
            }
            fileFullPath = pathUtil.join(options.path, file);
            fileRelativePath = options.relativePath ? pathUtil.join(options.relativePath, file) : file;
            return balUtilPaths.isDirectory(fileFullPath, function(err, isDirectory, fileStat) {
              var complete;
              if (tasks.exited) {

              } else if (err) {
                console.log('balUtilPaths.scandir: isDirectory has failed on:', fileFullPath);
                return tasks.exit(err);
              } else if (isDirectory) {
                complete = function(err, skip, subtreeCallback) {
                  if (err) {
                    return tasks.exit(err);
                  }
                  if (tasks.exited) {
                    return tasks.exit();
                  }
                  if (skip !== true) {
                    list[fileRelativePath] = 'dir';
                    tree[file] = {};
                    if (!options.recurse) {
                      return tasks.complete();
                    } else {
                      return balUtilPaths.scandir({
                        path: fileFullPath,
                        relativePath: fileRelativePath,
                        fileAction: options.fileAction,
                        dirAction: options.dirAction,
                        readFiles: options.readFiles,
                        ignorePatterns: options.ignorePatterns,
                        ignoreHiddenFiles: options.ignoreHiddenFiles,
                        recurse: options.recurse,
                        stat: options.fileStat,
                        next: function(err, _list, _tree) {
                          var filePath, fileType;
                          tree[file] = _tree;
                          for (filePath in _list) {
                            if (!__hasProp.call(_list, filePath)) continue;
                            fileType = _list[filePath];
                            list[filePath] = fileType;
                          }
                          if (tasks.exited) {
                            return tasks.exit();
                          } else if (err) {
                            console.log('balUtilPaths.scandir: has failed on:', fileFullPath);
                            return tasks.exit(err);
                          } else if (subtreeCallback) {
                            return subtreeCallback(tasks.completer());
                          } else {
                            return tasks.complete();
                          }
                        }
                      });
                    }
                  } else {
                    return tasks.complete();
                  }
                };
                if (options.dirAction) {
                  return options.dirAction(fileFullPath, fileRelativePath, complete, fileStat);
                } else if (options.dirAction === false) {
                  return complete(err, true);
                } else {
                  return complete(err, false);
                }
              } else {
                complete = function(err, skip) {
                  if (err) {
                    return tasks.exit(err);
                  }
                  if (tasks.exited) {
                    return tasks.exit();
                  }
                  if (skip) {
                    return tasks.complete();
                  } else {
                    list[fileRelativePath] = 'file';
                    if (options.readFiles) {
                      return balUtilPaths.readFile(fileFullPath, function(err, data) {
                        if (err) {
                          return tasks.exit(err);
                        }
                        tree[file] = data.toString();
                        return tasks.complete();
                      });
                    } else {
                      tree[file] = true;
                      return tasks.complete();
                    }
                  }
                };
                if (options.fileAction) {
                  return options.fileAction(fileFullPath, fileRelativePath, complete, fileStat);
                } else if (options.fileAction === false) {
                  return complete(err, true);
                } else {
                  return complete(err, false);
                }
              }
            });
          });
        }
      });
      return this;
    },
    cpdir: function() {
      var args, err, ignoreHiddenFiles, ignorePatterns, next, outPath, scandirOptions, srcPath, _ref3;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      if (args.length === 1) {
        _ref3 = args[0], srcPath = _ref3.srcPath, outPath = _ref3.outPath, next = _ref3.next, ignoreHiddenFiles = _ref3.ignoreHiddenFiles, ignorePatterns = _ref3.ignorePatterns;
      } else if (args.length >= 3) {
        srcPath = args[0], outPath = args[1], next = args[2];
      } else {
        err = new Error('balUtilPaths.cpdir: unknown arguments');
        if (next) {
          return next(err);
        } else {
          throw err;
        }
      }
      scandirOptions = {
        path: srcPath,
        fileAction: function(fileSrcPath, fileRelativePath, next) {
          var fileOutPath;
          fileOutPath = pathUtil.join(outPath, fileRelativePath);
          return balUtilPaths.ensurePath(pathUtil.dirname(fileOutPath), function(err) {
            if (err) {
              console.log('balUtilPaths.cpdir: failed to create the path for the file:', fileSrcPath);
              return next(err);
            }
            return balUtilPaths.cp(fileSrcPath, fileOutPath, function(err) {
              if (err) {
                console.log('balUtilPaths.cpdir: failed to copy the child file:', fileSrcPath);
              }
              return next(err);
            });
          });
        },
        next: next
      };
      if (ignoreHiddenFiles != null) {
        scandirOptions.ignoreHiddenFiles = ignoreHiddenFiles;
      }
      if (ignorePatterns != null) {
        scandirOptions.ignorePatterns = ignorePatterns;
      }
      balUtilPaths.scandir(scandirOptions);
      return this;
    },
    rpdir: function() {
      var args, err, ignoreHiddenFiles, ignorePatterns, next, outPath, scandirOptions, srcPath, _ref3;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      if (args.length === 1) {
        _ref3 = args[0], srcPath = _ref3.srcPath, outPath = _ref3.outPath, next = _ref3.next, ignoreHiddenFiles = _ref3.ignoreHiddenFiles, ignorePatterns = _ref3.ignorePatterns;
      } else if (args.length >= 3) {
        srcPath = args[0], outPath = args[1], next = args[2];
      } else {
        err = new Error('balUtilPaths.cpdir: unknown arguments');
        if (next) {
          return next(err);
        } else {
          throw err;
        }
      }
      scandirOptions = {
        path: srcPath,
        fileAction: function(fileSrcPath, fileRelativePath, next) {
          var fileOutPath;
          fileOutPath = pathUtil.join(outPath, fileRelativePath);
          return balUtilPaths.ensurePath(pathUtil.dirname(fileOutPath), function(err) {
            if (err) {
              console.log('balUtilPaths.rpdir: failed to create the path for the file:', fileSrcPath);
              return next(err);
            }
            return balUtilPaths.isPathOlderThan(fileOutPath, fileSrcPath, function(err, older) {
              if (older === true || older === null) {
                return balUtilPaths.cp(fileSrcPath, fileOutPath, function(err) {
                  if (err) {
                    console.log('balUtilPaths.rpdir: failed to copy the child file:', fileSrcPath);
                  }
                  return next(err);
                });
              } else {
                return next();
              }
            });
          });
        },
        next: next
      };
      if (ignoreHiddenFiles != null) {
        scandirOptions.ignoreHiddenFiles = ignoreHiddenFiles;
      }
      if (ignorePatterns != null) {
        scandirOptions.ignorePatterns = ignorePatterns;
      }
      balUtilPaths.scandir(scandirOptions);
      return this;
    },
    rmdirDeep: function(parentPath, next) {
      balUtilPaths.exists(parentPath, function(exists) {
        if (!exists) {
          return next();
        }
        return balUtilPaths.scandir(parentPath, function(fileFullPath, fileRelativePath, next) {
          return balUtilPaths.unlink(fileFullPath, function(err) {
            if (err) {
              console.log('balUtilPaths.rmdirDeep: failed to remove the child file:', fileFullPath);
            }
            return next(err);
          });
        }, function(fileFullPath, fileRelativePath, next) {
          return next(null, false, function(next) {
            return balUtilPaths.rmdirDeep(fileFullPath, function(err) {
              if (err) {
                console.log('balUtilPaths.rmdirDeep: failed to remove the child directory:', fileFullPath);
              }
              return next(err);
            });
          });
        }, function(err, list, tree) {
          if (err) {
            return next(err, list, tree);
          }
          return balUtilPaths.rmdir(parentPath, function(err) {
            if (err) {
              console.log('balUtilPaths.rmdirDeep: failed to remove the parent directory:', parentPath);
            }
            return next(err, list, tree);
          });
        });
      });
      return this;
    },
    writetree: function(dstPath, tree, next) {
      var tasks;
      tasks = new balUtilFlow.Group(function(err) {
        return next(err);
      });
      balUtilPaths.ensurePath(dstPath, function(err) {
        var fileFullPath, fileRelativePath, value;
        if (err) {
          return tasks.exit(err);
        }
        for (fileRelativePath in tree) {
          if (!__hasProp.call(tree, fileRelativePath)) continue;
          value = tree[fileRelativePath];
          ++tasks.total;
          fileFullPath = pathUtil.join(dstPath, fileRelativePath.replace(/^\/+/, ''));
          if (typeof value === 'object') {
            balUtilPaths.writetree(fileFullPath, value, tasks.completer());
          } else {
            balUtilPaths.writeFile(fileFullPath, value, function(err) {
              if (err) {
                console.log('balUtilPaths.writetree: writeFile failed on:', fileFullPath);
              }
              return tasks.complete(err);
            });
          }
        }
        if (tasks.total === 0) {
          tasks.exit();
        }
      });
      return this;
    },
    readPath: function(filePath, next) {
      var http, requestOptions;
      if (/^http/.test(filePath)) {
        requestOptions = require('url').parse(filePath);
        http = requestOptions.protocol === 'https:' ? require('https') : require('http');
        http.get(requestOptions, function(res) {
          var data;
          data = '';
          res.on('data', function(chunk) {
            return data += chunk;
          });
          return res.on('end', function() {
            return next(null, data);
          });
        }).on('error', function(err) {
          return next(err);
        });
      } else {
        balUtilPaths.readFile(filePath, function(err, data) {
          if (err) {
            return next(err);
          }
          return next(null, data);
        });
      }
      return this;
    },
    empty: function(filePath, next) {
      balUtilPaths.exists(filePath, function(exists) {
        if (!exists) {
          return next(null, true);
        }
        return balUtilPaths.stat(filePath, function(err, stat) {
          if (err) {
            return next(err);
          }
          return next(null, stat.size === 0);
        });
      });
      return this;
    },
    isPathOlderThan: function(aPath, bInput, next) {
      var bMtime, bPath, mode;
      bMtime = null;
      if (typeof bInput === 'number') {
        mode = 'time';
        bMtime = new Date(new Date() - bInput);
      } else {
        mode = 'path';
        bPath = bInput;
      }
      balUtilPaths.empty(aPath, function(err, empty) {
        if (empty || err) {
          return next(err, null);
        }
        return balUtilPaths.stat(aPath, function(err, aStat) {
          var compare;
          if (err) {
            return next(err);
          }
          compare = function() {
            var older;
            if (aStat.mtime < bMtime) {
              older = true;
            } else {
              older = false;
            }
            return next(null, older);
          };
          if (mode === 'path') {
            return balUtilPaths.empty(bPath, function(err, empty) {
              if (empty || err) {
                return next(err, null);
              }
              return balUtilPaths.stat(bPath, function(err, bStat) {
                if (err) {
                  return next(err);
                }
                bMtime = bStat.mtime;
                return compare();
              });
            });
          } else {
            return compare();
          }
        });
      });
      return this;
    }
  };

  module.exports = balUtilPaths;

}).call(this);