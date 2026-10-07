class ResultData {
  final String studentId;
  final String studentName;
  final String subject;
  final String term;
  final String testNumber;
  final double marksObtained;
  final double totalMarks;

  ResultData({
    required this.studentId,
    required this.studentName,
    required this.subject,
    required this.term,
    required this.testNumber,
    required this.marksObtained,
    this.totalMarks = 100,
  });

  double get percentage => (marksObtained / totalMarks) * 100;
}
