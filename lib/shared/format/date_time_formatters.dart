String formatDateTimeYmdHm(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${_twoDigits(local.month)}-'
      '${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:'
      '${_twoDigits(local.minute)}';
}

String formatDateTimeMdHm(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  return '${_twoDigits(local.month)}/${_twoDigits(local.day)} '
      '${_twoDigits(local.hour)}:'
      '${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
