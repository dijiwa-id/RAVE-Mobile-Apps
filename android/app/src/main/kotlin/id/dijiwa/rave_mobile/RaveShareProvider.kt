package id.dijiwa.rave_mobile

import androidx.core.content.FileProvider

// FileProvider sendiri (kelas turunan) agar tidak bentrok dengan provider share_plus di manifest gabungan.
class RaveShareProvider : FileProvider()
