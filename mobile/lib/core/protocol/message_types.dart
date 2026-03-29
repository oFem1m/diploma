class MessageTypes {
  static const hello = 'hello';
  static const ping = 'ping';
  static const pong = 'pong';
  static const error = 'error';
  static const chunk = 'chunk';
  static const cancel = 'cancel';
  static const jobSubmit = 'job.submit';
  static const jobAccepted = 'job.accepted';
  static const jobQueued = 'job.queued';
  static const jobStarted = 'job.started';
  static const jobProgress = 'job.progress';
  static const jobResult = 'job.result';
  static const jobFinished = 'job.finished';
  static const jobStatusGet = 'job.status.get';
  static const jobStatus = 'job.status';
}
