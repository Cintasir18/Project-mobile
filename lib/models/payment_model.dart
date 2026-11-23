class PaymentModel {
  final int id; final String userId; final String period; final double amount;
  final double paidAmount; final String status; final String? dueDate; final String? paidAt;
  const PaymentModel({required this.id, required this.userId, required this.period, required this.amount, this.paidAmount = 0, required this.status, this.dueDate, this.paidAt});
  bool get isPaid => status.toLowerCase() == 'paid';
  factory PaymentModel.fromMap(Map<String, dynamic> map) => PaymentModel(
    id: int.tryParse('${map['id']}') ?? 0, userId: map['user_id']?.toString() ?? '',
    period: map['period']?.toString() ?? '', amount: double.tryParse('${map['amount']}') ?? 0,
    paidAmount: double.tryParse('${map['paid_amount'] ?? 0}') ?? 0,
    status: map['status']?.toString() ?? 'unpaid', dueDate: map['due_date']?.toString(), paidAt: map['paid_at']?.toString(),
  );
}
