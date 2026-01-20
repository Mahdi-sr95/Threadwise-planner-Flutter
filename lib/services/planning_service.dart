import '../models/plan_request.dart';
import '../models/plan_result.dart';
import '../models/enums.dart';

abstract class PlanningService {
  Future<PlanResult> generatePlan(PlanRequest request);
  
  Future<InputStatus> validateInput(String input);
  
  Future<bool> testConnection();
}
