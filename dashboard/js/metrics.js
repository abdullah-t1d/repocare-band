// @ts-check
// Metric catalogue: what each WearableReading field is, where it comes from and
// how far it is through hardware validation. Update `validation` as test results
// come in; a metric marked 'rejected' disappears from the overview automatically
// (it stays listed in the Engineering / Sensor Debug section).

/**
 * @typedef {'testing' | 'candidate' | 'accepted' | 'rejected'} ValidationStatus
 * measured: read from a sensor · estimate: computed from a sensor but known to be approximate
 * derived: combined from several readings · experimental: derived and not yet trusted at all
 * @typedef {'measured' | 'estimate' | 'derived' | 'experimental'} MetricKind
 *
 * @typedef {Object} MetricInfo
 * @property {string} label
 * @property {string} unit         '' for states
 * @property {string} source
 * @property {MetricKind} kind
 * @property {ValidationStatus} validation
 */

/** @type {Readonly<Record<Exclude<keyof WearableReading, 'timestamp'>, MetricInfo>>} */
const METRICS = Object.freeze({
  heartRate:        { label: 'معدل النبض', unit: 'BPM', source: 'MAX30102', kind: 'measured', validation: 'candidate' },
  spo2:             { label: 'الأكسجين في الدم', unit: '%', source: 'MAX30102 (Red + IR)', kind: 'estimate', validation: 'testing' },
  skinTemperature:  { label: 'درجة حرارة الجلد', unit: '°C', source: 'AS6221', kind: 'measured', validation: 'testing' },
  stressLevel:      { label: 'مستوى التوتر', unit: '', source: 'HR/HRV + الحرارة + الحركة', kind: 'derived', validation: 'testing' },
  steps:            { label: 'خطوات اليوم', unit: 'خطوة', source: 'IMU (XIAO Sense)', kind: 'derived', validation: 'testing' },
  activity:         { label: 'حالة النشاط', unit: '', source: 'IMU (XIAO Sense)', kind: 'derived', validation: 'testing' },
  motionIntensity:  { label: 'شدة الحركة', unit: '', source: 'IMU (XIAO Sense)', kind: 'measured', validation: 'testing' },
  hrv:              { label: 'تقلب النبض (HRV/PRV)', unit: 'ms', source: 'MAX30102 · RMSSD', kind: 'experimental', validation: 'testing' },
  recoveryScore:    { label: 'درجة التعافي', unit: '/ 100', source: 'HRV + نبض الراحة + الحرارة + النشاط', kind: 'experimental', validation: 'testing' },
  restingHeartRate: { label: 'نبض الراحة', unit: 'BPM', source: 'MAX30102 + IMU', kind: 'experimental', validation: 'testing' },
  signalQuality:    { label: 'جودة الإشارة', unit: '', source: 'MAX30102 (firmware)', kind: 'derived', validation: 'candidate' },
  rawIR:            { label: 'IR خام', unit: '', source: 'MAX30102', kind: 'measured', validation: 'accepted' },
  rawRed:           { label: 'Red خام', unit: '', source: 'MAX30102', kind: 'measured', validation: 'accepted' },
  beatDetected:     { label: 'اكتشاف النبضة', unit: '', source: 'MAX30102 (firmware)', kind: 'derived', validation: 'candidate' },
  sensorContact:    { label: 'تلامس الحساس', unit: '', source: 'MAX30102 (firmware)', kind: 'derived', validation: 'candidate' },
});

const KIND_TAGS = Object.freeze({ measured: '', estimate: 'تقديري', derived: 'مشتق', experimental: 'تجريبي' });
const VALIDATION_LABELS = Object.freeze({ testing: 'قيد الاختبار', candidate: 'مرشّح', accepted: 'معتمد', rejected: 'مستبعد' });

/** @param {keyof typeof METRICS} key */
const isMetricShown = key => METRICS[key].validation !== 'rejected';
