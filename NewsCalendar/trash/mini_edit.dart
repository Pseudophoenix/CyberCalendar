// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../models/events.dart';

// class MiniEdit extends StatefulWidget {
//   final Event event;
//   final bool editing;

//   const MiniEdit({Key? key, required this.event, required this.editing})
//     : super(key: key);

//   @override
//   State<MiniEdit> createState() => _MiniEditState();
// }

// class _MiniEditState extends State<MiniEdit> {
//   late Event _editedEvent;
//   final _formKey = GlobalKey<FormState>();

//   @override
//   void initState() {
//     super.initState();
//     _editedEvent = Event.copy(widget.event);
//   }

//   Future<void> _selectStartDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _editedEvent.startDate,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//     );
//     if (picked != null && picked != _editedEvent.startDate) {
//       setState(() {
//         _editedEvent = _editedEvent.copyWith(
//           startDate: picked,
//           endDate:
//               (_editedEvent.endDate != null &&
//                       _editedEvent.endDate!.isBefore(picked))
//                   ? picked
//                   : _editedEvent.endDate,
//         );
//       });
//     }
//   }

//   Future<void> _selectEndDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _editedEvent.endDate ?? _editedEvent.startDate,
//       firstDate: _editedEvent.startDate,
//       lastDate: DateTime(2100),
//     );
//     if (picked != null && picked != _editedEvent.endDate) {
//       setState(() {
//         _editedEvent = _editedEvent.copyWith(endDate: picked);
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: Theme.of(context).colorScheme.surface,
//         borderRadius: BorderRadius.circular(12.0),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.2),
//             blurRadius: 8.0,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   widget.editing ? 'Edit Event' : 'View Event',
//                   style: Theme.of(context).textTheme.titleLarge,
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.close),
//                   onPressed: () => Navigator.pop(context),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16.0),
//             TextFormField(
//               initialValue: _editedEvent.title,
//               decoration: const InputDecoration(
//                 labelText: 'Title *',
//                 hintText: 'Enter event title',
//               ),
//               enabled: widget.editing,
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Title is required';
//                 }
//                 return null;
//               },
//               onSaved:
//                   (value) =>
//                       _editedEvent = _editedEvent.copyWith(title: value ?? ''),
//             ),
//             const SizedBox(height: 12.0),
//             TextFormField(
//               initialValue: _editedEvent.description,
//               decoration: const InputDecoration(
//                 labelText: 'Description',
//                 hintText: 'Add details (optional)',
//               ),
//               enabled: widget.editing,
//               maxLines: 3,
//               onSaved:
//                   (value) =>
//                       _editedEvent = _editedEvent.copyWith(description: value),
//             ),
//             const SizedBox(height: 12.0),
//             // Start Date Field
//             ListTile(
//               contentPadding: EdgeInsets.zero,
//               title: const Text('Start Date *'),
//               subtitle: Text(
//                 DateFormat('dd-MM-yyyy').format(_editedEvent.startDate),
//                 style: Theme.of(context).textTheme.bodyLarge,
//               ),
//               trailing:
//                   widget.editing
//                       ? IconButton(
//                         icon: const Icon(Icons.calendar_today),
//                         onPressed: () => _selectStartDate(context),
//                       )
//                       : null,
//             ),
//             const SizedBox(height: 8.0),
//             // End Date Field
//             ListTile(
//               contentPadding: EdgeInsets.zero,
//               title: const Text('End Date (optional)'),
//               subtitle: Text(
//                 _editedEvent.endDate != null
//                     ? DateFormat('dd-MM-yyyy').format(_editedEvent.endDate!)
//                     : 'No end date',
//                 style: Theme.of(context).textTheme.bodyLarge,
//               ),
//               trailing:
//                   widget.editing
//                       ? Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           if (_editedEvent.endDate != null)
//                             IconButton(
//                               icon: const Icon(Icons.clear),
//                               onPressed: () {
//                                 setState(() {
//                                   _editedEvent = _editedEvent.copyWith(
//                                     endDate: null,
//                                   );
//                                 });
//                               },
//                             ),
//                           IconButton(
//                             icon: const Icon(Icons.calendar_today),
//                             onPressed: () => _selectEndDate(context),
//                           ),
//                         ],
//                       )
//                       : null,
//             ),
//             if (widget.editing) ...[
//               const SizedBox(height: 24.0),
//               ElevatedButton(
//                 onPressed: _saveChanges,
//                 child: const Text('Save Changes'),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   // void _saveChanges() {
//   //   // Safely get the form state
//   //   final formState = _formKey.currentState;

//   //   // Return early if form isn't valid
//   //   if (formState == null || !formState.validate()) {
//   //     return;
//   //   }

//   //   // Save form data
//   //   formState.save();

//   //   // Create updated event with guaranteed non-null values
//   //   final updatedEvent = Event(
//   //     id: _editedEvent.id ?? '',
//   //     title: _editedEvent.title ?? '',
//   //     description: _editedEvent.description ?? '',
//   //     startDate: _editedEvent.startDate,
//   //     endDate: _editedEvent.endDate,
//   //     userId: _editedEvent.userId ?? '',
//   //     createdAt: _editedEvent.createdAt,
//   //     updatedAt: DateTime.now(),
//   //   );

//   //   // Return the updated event if widget is still mounted
//   //   if (mounted) {
//   //     Navigator.pop(context, updatedEvent);
//   //   }
//   // }

//   void _saveChanges() {
//     final formState = _formKey.currentState;
//     if (formState == null || !formState.validate()) return;

//     formState.save();

//     // Ensure we have a proper ID
//     final eventId =
//         _editedEvent.id ?? DateTime.now().millisecondsSinceEpoch.toString();

//     final updatedEvent = Event(
//       id: eventId, // Use existing ID or generate new one
//       title:
//           _editedEvent.title.isNotEmpty ? _editedEvent.title : 'Untitled Event',
//       description: _editedEvent.description ?? '',
//       startDate: _editedEvent.startDate,
//       endDate: _editedEvent.endDate,
//       userId: _editedEvent.userId ?? '',
//       createdAt: _editedEvent.createdAt,
//       updatedAt: DateTime.now(),
//     );

//     if (mounted) {
//       Navigator.pop(context, updatedEvent);
//     }
//   }
// }
