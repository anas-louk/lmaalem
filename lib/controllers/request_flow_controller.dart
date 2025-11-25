import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/enums/request_flow_state.dart';
import '../core/utils/logger.dart';
import '../data/models/accepted_employee_summary.dart';
import '../data/models/request_model.dart';
import '../data/repositories/request_repository.dart';
import 'auth_controller.dart';

/// Contrôleur dédié au mode focus d'une demande client
class RequestFlowController extends GetxController {
  RequestFlowController();

  final RequestRepository _requestRepository = RequestRepository();
  final AuthController _authController = Get.find<AuthController>();

  final Rx<RequestFlowState> currentState = RequestFlowState.idle.obs;
  final Rxn<RequestModel> activeRequest = Rxn<RequestModel>();
  final RxBool navigationLocked = false.obs;

  static const String _prefsActiveRequestIdKey = 'request_flow_active_request_id';
  static const String _prefsStateKey = 'request_flow_state';

  SharedPreferences? _prefs;
  StreamSubscription<RequestModel?>? _requestSubscription;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  @override
  void onClose() {
    _requestSubscription?.cancel();
    super.onClose();
  }

  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _restoreFromPreferences();
      await _syncWithServer();
    } catch (e, stackTrace) {
      Logger.logError('RequestFlowController._initialize', e, stackTrace);
    }
  }

  Future<void> _restoreFromPreferences() async {
    final savedState = _prefs?.getString(_prefsStateKey);
    final savedRequestId = _prefs?.getString(_prefsActiveRequestIdKey);

    if (savedState != null) {
      _applyState(
        RequestFlowStateX.fromValue(savedState),
        persistLocal: false,
        persistRemote: false,
      );
    }

    if (savedRequestId != null && savedRequestId.isNotEmpty) {
      await _subscribeToRequest(savedRequestId);
    }
  }

  Future<void> _syncWithServer() async {
    final user = _authController.currentUser.value;
    if (user == null) return;

    if (activeRequest.value != null) {
      // Already tracking a request, ensure local state matches
      await _persistState(activeRequest.value!.id, currentState.value);
      return;
    }

    try {
      final remoteRequest = await _requestRepository.getActiveRequestForClient(user.id);
      if (remoteRequest != null) {
        activeRequest.value = remoteRequest;
        await _subscribeToRequest(remoteRequest.id);
        await _persistState(remoteRequest.id, remoteRequest.requestStatus);
        _applyState(
          remoteRequest.requestStatus,
          persistRemote: false,
          persistLocal: false,
        );
      } else {  
        await clearFlow();
      }
    } catch (e, stackTrace) {
      Logger.logError('RequestFlowController._syncWithServer', e, stackTrace);
    }
  }

  Future<void> _subscribeToRequest(String requestId) async {
    await _requestSubscription?.cancel();
    _requestSubscription = _requestRepository.streamRequest(requestId).listen(
      (request) {
        if (request == null) {
          clearFlow();
          return;
        }
        activeRequest.value = request;
        _applyState(
          request.requestStatus,
          requestId: request.id,
          acceptedEmployee: request.employeeId != null ? AcceptedEmployeeSummary(id: request.employeeId!) : null,
          persistRemote: false,
        );

        if (request.requestStatus == RequestFlowState.completed ||
            request.requestStatus == RequestFlowState.canceled) {
          // Garder l'état jusqu'à ce qu'on nettoie explicitement côté UI
        }
      },
      onError: (error, stackTrace) {
        Logger.logError('RequestFlowController._subscribeToRequest', error, stackTrace);
      },
    );
  }

  /// Indique si une demande est en cours de traitement (pending ou accepted)
  bool get hasLockedRequest =>
      currentState.value == RequestFlowState.pending ||
      currentState.value == RequestFlowState.accepted;

  /// Forcer le contrôleur à suivre une nouvelle demande qui vient d'être créée
  Future<void> startPendingFlow(RequestModel request) async {
    activeRequest.value = request;
    await _subscribeToRequest(request.id);
    await _applyState(
      RequestFlowState.pending,
      requestId: request.id,
      acceptedEmployee: request.employeeId != null ? AcceptedEmployeeSummary(id: request.employeeId!) : null,
    );
  }

  /// Marquer la demande comme acceptée par un employé
  Future<void> markAccepted(AcceptedEmployeeSummary summary) async {
    if (activeRequest.value == null) return;
    // Mettre à jour le statut de la demande
    activeRequest.value = activeRequest.value!.copyWith(
      statut: 'Accepted',
      employeeId: summary.id,
    );
    await _applyState(
      RequestFlowState.accepted,
      requestId: activeRequest.value!.id,
      acceptedEmployee: summary,
    );
  }

  /// Marquer la demande comme terminée (succès)
  Future<void> markCompleted() async {
    if (activeRequest.value == null) return;
    await _applyState(
      RequestFlowState.completed,
      requestId: activeRequest.value!.id,
      acceptedEmployee: activeRequest.value!.acceptedEmployee,
    );
    await clearFlow();
  }

  /// Marquer la demande comme annulée (client)
  Future<void> markCanceled() async {
    if (activeRequest.value == null) return;
    await _applyState(
      RequestFlowState.canceled,
      requestId: activeRequest.value!.id,
      acceptedEmployee: activeRequest.value!.acceptedEmployee,
    );
    await clearFlow();
  }

  /// Nettoyer totalement le flux et repasser en mode idle
  Future<void> clearFlow() async {
    await _requestSubscription?.cancel();
    _requestSubscription = null;
    activeRequest.value = null;
    currentState.value = RequestFlowState.idle;
    navigationLocked.value = false;
    await _clearPreferences();
  }

  Future<void> _applyState(
    RequestFlowState state, {
    String? requestId,
    AcceptedEmployeeSummary? acceptedEmployee,
    bool persistRemote = true,
    bool persistLocal = true,
  }) async {
    currentState.value = state;
    navigationLocked.value = state.locksNavigation;

    final effectiveRequestId = requestId ?? activeRequest.value?.id;
    if (persistLocal && effectiveRequestId != null) {
      await _persistState(effectiveRequestId, state);
    } else if (persistLocal && state == RequestFlowState.idle) {
      await _clearPreferences();
    }

    if (persistRemote && effectiveRequestId != null) {
      try {
        await _requestRepository.updateRequestFlowFields(
          requestId: effectiveRequestId,
          flowState: state,
          acceptedEmployee: acceptedEmployee,
        );
      } catch (e, stackTrace) {
        Logger.logError('RequestFlowController._applyState', e, stackTrace);
      }
    }
  }

  Future<void> _persistState(String requestId, RequestFlowState state) async {
    await _prefs?.setString(_prefsActiveRequestIdKey, requestId);
    await _prefs?.setString(_prefsStateKey, state.value);
  }

  Future<void> _clearPreferences() async {
    await _prefs?.remove(_prefsActiveRequestIdKey);
    await _prefs?.remove(_prefsStateKey);
  }
}


