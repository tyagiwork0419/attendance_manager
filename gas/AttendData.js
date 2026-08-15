const Status = Object.freeze({
  normal: 'normal',
  deleted: 'deleted',
  none: 'none',

  fromString(str) {
    switch (str) {
      case 'normal':
        return Status.normal;
      case 'deleted':
        return Status.deleted;

      default:
        return none;
    }
  }
});

const AttendType = Object.freeze({
  clockIn: '出勤',
  clockOut: '退勤',
  paidHoliday: '有休',
  none: 'none',

  fromString(str) {
    switch (str) {
      case '出勤':
        return AttendType.clockIn;
      case '退勤':
        return AttendType.clockOut;
      case '有休':
        return AttendType.paidHoliday;

      default:
        return AttendType.none;
    }
  }
})

class AttendData {
  static get dateTimeFormat() { return 'yyyy/MM/dd HH:mm:ss' };
  static get timezone() { return 'Asia/Tokyo' };

  constructor(id, name, type, dateTime, status, remarks) {
    this.id = id;
    this.name = name;
    this.type = type;
    this.dateTime = dateTime;
    this.status = status;
    this.remarks = remarks;
  }

  static fromJson(json) {
    let id = json.id;
    let name = json.name;
    let type = AttendType.fromString(json.type);
    let dateTime = Utilities.parseDate(json.dateTime, AttendData.timezone, AttendData.dateTimeFormat);
    let status = Status.fromString(json.status);
    let remarks = json.remarks;
    return new AttendData(id, name, type, dateTime, status, remarks);
  }

  static getPropertyNames() {
    return ['id', 'name', 'type', 'dateTime', 'status', 'remarks'];
  }

  toJson() {
    return {
      'id': this.id,
      'name': this.name,
      'type': this.type,
      'dateTime': Utilities.formatDate(this.dateTime, AttendData.timezone, AttendData.dateTimeFormat),
      'status': this.status,
      'remarks': this.remarks,
    }
  }
}

