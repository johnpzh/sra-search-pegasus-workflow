/// flow-monitor/src/Lib.cpp

FILE *fopen64(const char *__restrict fileName, const char *__restrict modes) {
  assert(fileName && "Error: fileName is NULL.\n");
  DPRINTF("Lib.cpp: Calling fopen64 on %s \n", fileName);
  Timer::Metric metric = (modes[0] == 'r') ? Timer::Metric::in_fopen : Timer::Metric::out_fopen;

  for (auto pattern: patterns) {
    auto ret_val = fnmatch(pattern.c_str(), fileName, 0);
    if (ret_val == 0
    // && (strstr(fileName, "_r_stat") || strstr(fileName, "_w_stat") || strstr(fileName, "_trace_stat"))
    ) {
      DPRINTF("Lib.cpp: fopen64() Found pattern [%s] \n", pattern.c_str());
      return outerWrapper("fopen64", fileName, metric, trackFileFopen, unixfopen64,
			  fileName, modes);
    }
  }

    return outerWrapper("fopen64", fileName, metric, monitorFopen, unixfopen64, fileName, modes);
}

/// flow-monitor/inc/Lib.h
template <typename FileId, typename Func, typename FuncPosix, typename... Args>
auto outerWrapper(const char *name, FileId fileId, Timer::Metric metric, Func monitorFun, FuncPosix posixFun, Args... args) {
    DDPRINTF("Lib.h: outerWrapper() for function: [%s] (init value: %d)\n", name, (int) init);

    if (!init) {
        posixFun = (FuncPosix)dlsym(RTLD_NEXT, name);
        return posixFun(args...);
    }
    auto retValue = innerWrapper(fileId, isMonitorFile, monitorFun, posixFun, args...);
    DPRINTF("Lib.h: outerWrapper() innerWrapper retValue: %ld\n", (long int) retValue);
}

/// flow-monitor/inc/Lib.h
template <typename Func, typename FuncPosix, typename... Args>
inline auto innerWrapper(const char *pathname, bool &isMonitorFile, Func monitorFun, FuncPosix posixFun, Args... args) {

  DPRINTF("[MONITOR] in innerwrapper const char *pathname: %s\n", pathname);

  for (auto pattern: patterns) {
    auto ret_val = fnmatch(pattern.c_str(), pathname, 0);
    if (ret_val == 0) {
        DPRINTF("PATTERN: %s PATHNAME: %s \n", pattern.c_str(), pathname);
        isMonitorFile = true;
        std::string filename(pathname);
        type = MonitorFile::TrackLocal;
        file = filename;
        path = filename;
        DPRINTF("Calling HDF/FITS open: \n");
        return monitorFun(file, path, type, args...);
    }
  }

  if (init && checkMeta(pathname, path, file, type)) {
    isMonitorFile = true;
    DPRINTF("monitorfun With file %s\n", pathname);
    return monitorFun(file, path, type, args...);
  }
  DPRINTF("[MONITOR] in innerwrapper calling posix\n");


  return posixFun(args...);
}

/// flow-monitor/src/Lib.cpp
FILE *trackFileFopen(std::string name, std::string metaName, MonitorFile::Type type, const char *__restrict fileName, const char *__restrict modes) {
  assert(fileName && "Error: fileName is NULL.\n");
  DPRINTF("Lib.cpp: trackFileFopen: %s %s %u\n", name.c_str(), metaName.c_str(), type);
  DPRINTF("Lib.cpp: in trackFileFopen\n");
  FILE *fp = (*unixfopen)(name.c_str(), modes);
  if (fp) {
    int fd = fileno(fp);
    MonitorFile *file = MonitorFile::addNewMonitorFile(type, name, metaName, fd);
    if (file) {
      MonitorFileDescriptor::addMonitorFileDescriptor(fd, file, file->newFilePosIndex());
      MonitorFileStream::addStream(fp, fd);
      DPRINTF("Lib.cpp: trackFileOpen add new  file success: %s , fd = %d\n", fileName, fd);
    }
  }
  return fp;
}

/// flow-monitor/src/MonitorFileStream.cpp
bool MonitorFileStream::addStream(FILE *fp, int fd) {
    return Trackable<FILE *, MonitorFileStream *>::AddTrackable(
               fp, [=]() -> MonitorFileStream * {
                   return new MonitorFileStream(fd);
               }) != NULL;
}

/// flow-monitor/inc/Trackable.h
static Value AddTrackable(Key k, std::function<Value(void)> createNew) {
    bool dontCare;
    return AddTrackable(k, createNew, NULL, dontCare);
}

/// flow-monitor/inc/Trackable.h
static Value AddTrackable(Key k, std::function<Value(void)> createNew, std::function<void(Value)> reuseOld, bool &created) {
    Value ret = NULL;
    _activeMutex.writerLock();
    if (!_active.count(k)) {
        ret = createNew();
        if (ret) {
            _active[k] = ret;
            created = true;
        }
    }
    else {
        ret = _active[k];
        if (reuseOld)
            reuseOld(ret);
        // if (ret){
        //     DPRINTF("reusing %s\n",typeid(ret).name());
        // }
    }

    if (ret)
        ret->incUsers();

    _activeMutex.writerUnlock();
    return ret;
}