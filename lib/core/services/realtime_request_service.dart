import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/request_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/request_repository.dart';
import '../../data/repositories/employee_repository.dart';
import '../../core/utils/logger.dart';

/// Service pour les mises à jour en temps réel des demandes et employés acceptés
class RealtimeRequestService {
  final RequestRepository _requestRepository = RequestRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<RequestModel?>? _requestSubscription;
  StreamSubscription<DocumentSnapshot>? _employeesSubscription;
  
  final _requestController = StreamController<RequestModel?>.broadcast();
  final _employeesController = StreamController<List<EmployeeModel>>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  /// Stream de la demande active
  Stream<RequestModel?> get requestStream => _requestController.stream;

  /// Stream de la liste des employés acceptés
  Stream<List<EmployeeModel>> get employeesStream => _employeesController.stream;

  /// Stream du statut de connexion
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  /// Écouter une demande spécifique en temps réel
  void listenToRequest(String requestId) {
    _requestSubscription?.cancel();
    
    _requestSubscription = _requestRepository.streamRequest(requestId).listen(
      (request) {
        if (!_requestController.isClosed) {
          _requestController.add(request);
          _updateConnectionStatus(true);
        }
      },
      onError: (error) {
        Logger.logError('RealtimeRequestService.listenToRequest', error, StackTrace.current);
        _updateConnectionStatus(false);
        if (!_requestController.isClosed) {
          _requestController.addError(error);
        }
      },
    );
  }

  /// Écouter les employés acceptés pour une demande en temps réel
  void listenToAcceptedEmployees(String requestId) {
    _employeesSubscription?.cancel();

    // Écouter la demande pour obtenir la liste des employés acceptés
    _requestSubscription = _requestRepository.streamRequest(requestId).listen(
      (request) async {
        if (request == null) {
          if (!_employeesController.isClosed) {
            _employeesController.add([]);
          }
          return;
        }

        final acceptedIds = request.acceptedEmployeeIds
            .where((id) => !request.clientRefusedEmployeeIds.contains(id))
            .toList();

        if (acceptedIds.isEmpty) {
          if (!_employeesController.isClosed) {
            _employeesController.add([]);
          }
          return;
        }

        // Charger les employés en parallèle
        try {
          // Vérifier avant l'opération asynchrone
          if (_employeesController.isClosed) return;
          
          final employees = <EmployeeModel>[];
          final futures = acceptedIds.map((id) => _employeeRepository.getEmployeeById(id));
          final results = await Future.wait(futures);

          for (final employee in results) {
            if (employee != null) {
              employees.add(employee);
            }
          }

          // Vérifier après l'opération asynchrone
          if (!_employeesController.isClosed) {
            _employeesController.add(employees);
            _updateConnectionStatus(true);
          }
        } catch (e) {
          Logger.logError('RealtimeRequestService.listenToAcceptedEmployees', e, StackTrace.current);
          _updateConnectionStatus(false);
          if (!_employeesController.isClosed) {
            try {
              _employeesController.addError(e);
            } catch (_) {
              // Ignorer si le controller est fermé entre temps
            }
          }
        }
      },
      onError: (error) {
        Logger.logError('RealtimeRequestService.listenToAcceptedEmployees', error, StackTrace.current);
        _updateConnectionStatus(false);
        if (!_employeesController.isClosed) {
          _employeesController.addError(error);
        }
      },
    );
  }

  /// Écouter les employés acceptés via une requête Firestore directe (plus efficace)
  void listenToAcceptedEmployeesDirect(String requestId) {
    // Annuler la subscription précédente
    _employeesSubscription?.cancel();
    _employeesSubscription = null;

    // Vérifier que le controller n'est pas fermé avant de créer une nouvelle subscription
    if (_employeesController.isClosed) {
      Logger.logError('RealtimeRequestService.listenToAcceptedEmployeesDirect', 
        'Cannot listen: employees controller is closed', StackTrace.current);
      return;
    }

    // Écouter directement le document de la demande
    _employeesSubscription = _firestore
        .collection('requests')
        .doc(requestId)
        .snapshots()
        .listen(
      (snapshot) async {
        // Vérifier immédiatement si le controller est fermé
        if (_employeesController.isClosed) return;
        
        if (!snapshot.exists || snapshot.data() == null) {
          if (!_employeesController.isClosed) {
            try {
              _employeesController.add([]);
            } catch (e) {
              // Controller fermé entre temps, ignorer
              return;
            }
          }
          return;
        }

        final data = snapshot.data()!;
        final acceptedIds = List<String>.from(data['acceptedEmployeeIds'] ?? []);
        final refusedIds = List<String>.from(data['clientRefusedEmployeeIds'] ?? []);

        final filteredIds = acceptedIds.where((id) => !refusedIds.contains(id)).toList();

        if (filteredIds.isEmpty) {
          if (!_employeesController.isClosed) {
            try {
              _employeesController.add([]);
            } catch (e) {
              // Controller fermé entre temps, ignorer
              return;
            }
          }
          return;
        }

        // Charger les employés en parallèle
        try {
          // Vérifier avant l'opération asynchrone
          if (_employeesController.isClosed) return;
          
          final employees = <EmployeeModel>[];
          final futures = filteredIds.map((id) => _employeeRepository.getEmployeeById(id));
          final results = await Future.wait(futures);

          for (final employee in results) {
            if (employee != null) {
              employees.add(employee);
            }
          }

          // Vérifier après l'opération asynchrone (le controller peut avoir été fermé entre temps)
          if (!_employeesController.isClosed) {
            try {
              _employeesController.add(employees);
              _updateConnectionStatus(true);
            } catch (e) {
              // Controller fermé entre temps, ignorer silencieusement
              debugPrint('RealtimeRequestService: Controller closed during async operation');
            }
          }
        } catch (e) {
          Logger.logError('RealtimeRequestService.listenToAcceptedEmployeesDirect', e, StackTrace.current);
          _updateConnectionStatus(false);
          // Ne pas ajouter d'erreur si le controller est fermé
          if (!_employeesController.isClosed) {
            try {
              _employeesController.addError(e);
            } catch (_) {
              // Ignorer si le controller est fermé entre temps
            }
          }
        }
      },
      onError: (error) {
        Logger.logError('RealtimeRequestService.listenToAcceptedEmployeesDirect', error, StackTrace.current);
        _updateConnectionStatus(false);
        if (!_employeesController.isClosed) {
          try {
            _employeesController.addError(error);
          } catch (_) {
            // Ignorer si le controller est fermé
          }
        }
      },
    );
  }

  void _updateConnectionStatus(bool connected) {
    if (_isConnected != connected && !_connectionStatusController.isClosed) {
      _isConnected = connected;
      _connectionStatusController.add(connected);
    }
  }

  /// Arrêter tous les streams (sans fermer les controllers pour permettre la réutilisation)
  void stop() {
    _requestSubscription?.cancel();
    _requestSubscription = null;
    _employeesSubscription?.cancel();
    _employeesSubscription = null;
  }

  /// Arrêter tous les streams et fermer les controllers (appelé uniquement lors du dispose final)
  void dispose() {
    stop();
    if (!_requestController.isClosed) {
      _requestController.close();
    }
    if (!_employeesController.isClosed) {
      _employeesController.close();
    }
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.close();
    }
  }
}

