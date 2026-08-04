import 'package:csv/csv.dart';

void main() {
  print(const CsvEncoder().convert([
    [1, 2, 3]
  ]));
}
