**Tech Stack:** 



● Language: Dart, Javascript

● Framework: Express.js, React, Flutter

● Styling: Dart based widget styling, Tailwind CSS

● Database: PostgreSQL

● ORM: Prisma

● Deployment: Oracle Cloud





**Functional requirements:**



Module 1:

1\. \[Member-1] Investors can invest in products. If a product got 100% investment then the producer will confirm the order and deliver the product on time. In the meantime the investor can list the product in the rentable product pool where any renter will be able to rent the product. To make any decision ( Increase or decrease rent price ) with the product, investors need to come up with a decision by voting. The voting system will be a weighted voting scheme where weight is their share in that product. Investors can keep the product to their place or in our warehouse. To keep in our warehouse they have to pay a security fee every month according to the product's size, weight and price. Investors can see the live location of the product. For the live location feature investors need to pay an additional safety fee.





2\. \[Member-2] Renters, Investor can securely pay using sslcommerz. Producers can make a withdrawal request to the Admins. Admins can review and process a withdrawal request to confirm and notify the Producers.





3\. \[Member-3] Producers can list the products they are offering and post it with different images and videos and info about the product with a production time ( instant/ n numbers of days). Each listing will have a comment section where the producer can replay. A review section where investors who have invested can leave a review any time. All listings will have an upvote and downvote system.



Module 2:

1\. \[Member-1] Users can add publicly available rental assets to a personal watchlist and configure alerts based on asset availability, rental price, and funding status. The system will monitor changes to watched assets and send notifications through email when configured conditions are met. Users can view, add, remove, and manage their watched assets from the watchlist.

2\. \[Member-2] Admin can view or edit or manage every producer's post. Admin can notify them if they did anything wrong. Admin can also temporarily block any producer, investor, renter’s account from using the platform and if they did then the user will get an email. Every blocked account will be frozen until the user proves their innocence.

3\. \[Member-3] There will be a tag along with every user, if they are verified by only email or with a KYC face verification. ( Renter, Investor, Producer) Users can do the KYC verification anytime from the app.





Module 3:

1\. \[Member-1] Renters can explore and search nearby rental assets using an interactive map interface (powered by Leaflet/OpenStreetMap or Google Maps API). Users can filter products by distance, category, price range, and real-time availability. The map fetches asset coordinates, groups nearby listings into clusters, and displays interactive pins showing product thumbnails, hourly/daily rental rates, and direct links to booking checkout.

2\. \[Member-1] Once a rental booking is confirmed via SSLCommerz, renters gain access to an active rental portal. This features a real-time countdown timer for the rental duration, live status tracking (e.g., Pending Pickup, Active, Returned), and an auto-generated QR-coded digital gate-pass. Warehouse managers scan this QR code at the physical facility to verify and log product pick-up and return.





3\. \[Member-2] Fractional investors can communicate in real-time within individual asset split-buying threads using Socket.io web-sockets. The chat supports real-time message broadcasting, media sharing, and structured system messages that display funding progress updates. Prospective co-owners can discuss usage schedules, asset equity splits, and strategies directly within the channel prior to committing funds.

4\. \[Member-2] Co-owners can request current location data for assets equipped with IoT tracking hardware. Clicking a "Refresh Location" button triggers an API query to retrieve and render the asset’s latest cached GPS coordinates on a visual map interface. Additionally, the system automatically calculates and displays monthly accrued warehouse safety fees based on the asset's weight, dimensions, and declared value, deducting fees proportionally from the owners' rental dividend ledgers.





5\. \[Member-3] Verified manufacturers can create asset listing campaigns by uploading multi-media files (photos/videos), specifying technical specifications, setting target funding goals, and configuring custom rental pricing models. The backend logs these entries in PostgreSQL and exposes a real-time funding tracker with progress bars showing active syndicate split-buying attempts toward reaching 100% capitalization. 

6\. \[Member-3] Platform administrators have access to an operational fleet management map that plots the real-time location and movement history of all active market assets. Admins can view breadcrumb tracking trails, speed logs, and historical route playbacks for any unit, as well as set up geofence parameters that generate automated security alerts if an asset strays outside designated operating boundaries.

