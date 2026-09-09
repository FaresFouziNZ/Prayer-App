/// Why a prayer was logged as `late` or `missed`, picked from a fixed set
/// of reasons (no free text) so History and Stats can eventually break
/// missed/late prayers down by cause. Meaningless for `jamaah`/`onTimeAlone`
/// — callers only set it alongside those two statuses.
enum PrayerExcuse { overslept, busy, forgot, travel, sick, other }
