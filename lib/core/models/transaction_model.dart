/// Represents the Transaction entity from the database.
class Transaction {
  final String id; // Using UUID for unique identification
  final int accountId;
  final String type; // 'income' or 'expense'
  final double amount;
  final String? description;
  final DateTime transactionDate;
  final int createdByUserId;
  final String? remark; // Optional note
  final String? receiptImage; // Optional path to receipt image
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    this.description,
    required this.transactionDate,
    this.remark,
    this.receiptImage,
    required this.createdByUserId,
    required this.createdAt,
  });

  /// Converts a Transaction instance into a Map.
  /// The keys must correspond to the names of the columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'type': type,
      'amount': amount,
      'description': description,
      'transaction_date': transactionDate.toIso8601String(),
      'remark': remark,
      'receipt_image': receiptImage,
      'created_by_user_id': createdByUserId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a Transaction instance from a map.
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      accountId: map['account_id'] as int,
      type: map['type'] as String,
      // Ensure amount is read as a number (double or int)
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      remark: map['remark'] as String?,
      receiptImage: map['receipt_image'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      createdByUserId: map['created_by_user_id'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
