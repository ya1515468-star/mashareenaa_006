import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order_entity.dart';
import '../providers/marketplace_provider.dart';

class MyOrdersPage extends ConsumerStatefulWidget {
  const MyOrdersPage({super.key});

  @override
  ConsumerState<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends ConsumerState<MyOrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        bottom: TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'مشترياتي'), Tab(text: 'مبيعاتي')]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_BuyerOrdersTab(), _SellerOrdersTab()],
      ),
    );
  }
}

class _BuyerOrdersTab extends ConsumerWidget {
  const _BuyerOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersAsBuyerProvider);
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(child: Text('لا توجد مشتريات بعد'));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) =>
              _OrderTile(order: orders[index], isSellerView: false),
        );
      },
    );
  }
}

class _SellerOrdersTab extends ConsumerWidget {
  const _SellerOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersAsSellerProvider);
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(child: Text('لا توجد مبيعات بعد'));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) =>
              _OrderTile(order: orders[index], isSellerView: true),
        );
      },
    );
  }
}

class _OrderTile extends ConsumerWidget {
  final OrderEntity order;
  final bool isSellerView;
  const _OrderTile({required this.order, required this.isSellerView});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return ListTile(
      title: Text(order.listingTitle),
      subtitle: Text('${order.totalPrice.formatted} — ${order.status.label}'),
      trailing: isSellerView &&
              myUid != null &&
              order.status != OrderStatus.completed &&
              order.status != OrderStatus.cancelled
          ? PopupMenuButton<OrderStatus>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (status) {
                ref
                    .read(marketplaceControllerProvider.notifier)
                    .updateOrderStatus(
                      order: order,
                      newStatus: status,
                      requestedByUid: myUid,
                    );
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                    value: OrderStatus.confirmed, child: Text('تأكيد')),
                PopupMenuItem(value: OrderStatus.shipped, child: Text('شحن')),
                PopupMenuItem(
                    value: OrderStatus.completed, child: Text('إتمام')),
                PopupMenuItem(
                    value: OrderStatus.cancelled, child: Text('إلغاء')),
              ],
            )
          : null,
    );
  }
}
