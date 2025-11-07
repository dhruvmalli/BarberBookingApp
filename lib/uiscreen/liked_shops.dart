import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/liked_shops_provider.dart';
import 'bottom_nav_bar.dart';

class LikedShops extends StatefulWidget {
  const LikedShops({super.key});

  @override
  State<LikedShops> createState() => _LikedShopsState();
}

class _LikedShopsState extends State<LikedShops> {
  // Track removed items by index to trigger animation
  final Set<int> _fadingItems = {};

  @override
  Widget build(BuildContext context) {
    final likedShopsProvider = context.watch<LikedShopsProvider>();
    final likedShops = likedShopsProvider.likedShops;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const BottomNavBar(initialIndex: 0)),
            );
          },
        ),
        title: const Text(
          "Liked Shops",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: likedShops.isEmpty
          ? const Center(child: Text('No liked shops'))
          : SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(

              height: 475,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: likedShops.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final barber = likedShops[index];
                  final isFading = _fadingItems.contains(index);

                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: isFading ? 0.0 : 1.0,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      child: isFading
                          ? const SizedBox.shrink()
                          : SizedBox(
                        width: 300,
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Stack(
                                children: [
                                  Padding(

                                    padding: const EdgeInsets.all(4.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(32),
                                      child: Image.network(
                                        barber.imageUrl,
                                        height: 260,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          height: 260,
                                          color: Colors.grey[300],
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IconButton(
                                      icon: const Icon(Icons.favorite, color: Color(0xFFF31E1E),size: 28,),
                                      onPressed: () {
                                        setState(() => _fadingItems.add(index));

                                        Future.delayed(const Duration(milliseconds: 400), () {
                                          context.read<LikedShopsProvider>().toggleLike(barber);
                                          setState(() => _fadingItems.remove(index));
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      barber.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      barber.address,
                                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 22, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text('${barber.distanceKm.toStringAsFixed(1)} km',
                                            style: const TextStyle(fontSize: 16)),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.star, size: 22, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text(barber.rating.toString(), style: const TextStyle(fontSize: 16)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(thickness: 1, indent: 16, endIndent: 16, height: 1),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: TextButton(
                                  onPressed: () {
                                    // Booking logic
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Book Now',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
