/// Central API paths used by the field staff application.
abstract final class ApiEndpoints {
  static const authForgotPassword = '/auth/forgot-password';
  static const authResetPassword = '/auth/reset-password';
  static const authChangePassword = '/auth/change-password';
  static const billing = '/billing';
  static const billingConfig = '/billing/config';
  static const billingApprovals = '/billing/pending-approvals';
  static const overtime = '/overtime';
  static const overtimeEligibilityToday = '/overtime/eligibility/today';

  static String billingById(String id) => '$billing/$id';
  static String billingSubmit(String id) => '${billingById(id)}/submit';
  static String billingApprove(String id) => '${billingById(id)}/approve';
  static String billingReject(String id) => '${billingById(id)}/reject';
  static String billingHistory(String id) => '${billingById(id)}/history';
  static String billingAttachments(String id) =>
      '${billingById(id)}/attachments';
  static String overtimeDecision(String id) => '$overtime/$id/decision';
}
