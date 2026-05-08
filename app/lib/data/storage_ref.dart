/// Web PWA 内部参照の接頭辞（ファイルパスではない）。
const kWebTempPrefix = 'webtemp:';
const kWebStorePrefix = 'webstore:';

bool isWebTempRef(String s) => s.startsWith(kWebTempPrefix);
bool isWebStoreRef(String s) => s.startsWith(kWebStorePrefix);
