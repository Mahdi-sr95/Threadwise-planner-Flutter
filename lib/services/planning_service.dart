import '../models/plan_request.dart';
import '../models/plan_result.dart';
import '../models/enums.dart';

/// Contract for any planning service implementation (LLM-based or local).
abstract class PlanningService {
  /// Generates a plan based on the given request.
  Future<PlanResult> generatePlan(PlanRequest request);

  /// Validates whether the input is complete/unrelated.
  Future<InputStatus> validateInput(String input);

  /// Checks if the underlying service is reachable.
  Future<bool> testConnection();
}
