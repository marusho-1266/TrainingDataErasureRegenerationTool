import 'package:training_data_erasure/data/scan_repository_contract.dart';

import 'package:training_data_erasure/data/scan_repository_io.dart'
    if (dart.library.html) 'package:training_data_erasure/data/scan_repository_web.dart';

/// 実行プラットフォーム向けの [ScanRepository] を返す（Web は [WebScanRepository.instance]）。
ScanRepository createScanRepository() {
  return createScanRepositoryImpl();
}
