import 'package:attendance_management/models/planner_item.dart';
import 'package:attendance_management/services/local_db_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PlannerItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await LocalDbService.instance.getPlannerItems();
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load items: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Planner',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(completed: false),
                _buildList(completed: true),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        label: Text('Add Task', style: GoogleFonts.poppins()),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList({required bool completed}) {
    final filteredItems =
        _items.where((i) => i.isCompleted == completed).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              completed ? Icons.task_alt : Icons.event_note,
              size: 64,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              completed ? 'No completed tasks' : 'No pending tasks',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        final isOverdue =
            !item.isCompleted &&
            item.date.isBefore(
              DateTime.now().subtract(const Duration(days: 1)),
            );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Checkbox(
              value: item.isCompleted,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) async {
                if (val == null) return;
                item.isCompleted = val;
                await LocalDbService.instance.updatePlannerItem(item);
                _loadItems();
              },
            ),
            title: Text(
              item.title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                decoration: item.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.description.isNotEmpty)
                  Text(
                    item.description,
                    style: GoogleFonts.poppins(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.type == 'Exam'
                            ? Colors.red.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.type,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: item.type == 'Exam' ? Colors.red : Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, y').format(item.date),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isOverdue ? Colors.red : Colors.grey,
                        fontWeight: isOverdue
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (isOverdue) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Colors.red,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Task?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true && item.id != null) {
                  await LocalDbService.instance.deletePlannerItem(item.id!);
                  _loadItems();
                }
              },
            ),
            onTap: () => _showAddEditDialog(item: item),
          ),
        );
      },
    );
  }

  Future<void> _showAddEditDialog({PlannerItem? item}) async {
    final _formKey = GlobalKey<FormState>();
    String title = item?.title ?? '';
    String description = item?.description ?? '';
    String type = item?.type ?? 'Assignment';
    DateTime date = item?.date ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom:
              MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item == null ? 'Add New Task' : 'Edit Task',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: title,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
                onSaved: (v) => title = v ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: description,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSaved: (v) => description = v ?? '',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: type,
                      decoration: InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: ['Assignment', 'Exam']
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => type = v!,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          // keep logic simple for now
                          date = picked;
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Due Date',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(DateFormat('MMM d').format(date)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      final newItem = PlannerItem(
                        id: item?.id,
                        title: title,
                        description: description,
                        type: type,
                        date: date,
                        isCompleted: item?.isCompleted ?? false,
                      );

                      if (item == null) {
                        await LocalDbService.instance.addPlannerItem(newItem);
                      } else {
                        await LocalDbService.instance.updatePlannerItem(
                          newItem,
                        );
                      }
                      Navigator.pop(ctx);
                      _loadItems();
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(item == null ? 'Create Task' : 'Save Changes'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
