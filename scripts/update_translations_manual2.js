const fs = require('fs');
const files = ['en.json', 'fr.json', 'ar.json'];

const english = {
  'terms_content': '1. Acceptance of Terms\nBy accessing or using the Eventzone app, you agree to be bound by these Terms of Service. If you do not agree, please do not use the service.\n\n2. Description of Service\nEventzone is a B2B networking platform designed to help professionals connect at events.\n\n3. User Responsibilities\nYou are responsible for maintaining the confidentiality of your account and for all activities that occur under your account. You agree not to use the service for any illegal or unauthorized purpose.\n\n4. Subscriptions\nAn active subscription is required to continuously accept new connections and scan badges. Subscriptions can be purchased within the app and are subject to the pricing listed at the time of purchase.\n\n5. Termination\nWe reserve the right to suspend or terminate your account at any time for violations of these Terms.\n\n6. Changes to Terms\nWe may update these terms from time to time. Continued use of the app constitutes acceptance of any changes.',
  'privacy_content': '1. Information We Collect\nWe collect information you provide directly to us, such as your name, job title, company, email, and social links when you create a profile.\n\n2. How We Use Information\nWe use the information we collect to provide, maintain, and improve our services, and to facilitate connections with other users.\n\n3. Sharing of Information\nYour public profile information is shared with other users when they scan your QR code. We do not sell your personal information to third parties.\n\n4. Data Security\nWe implement appropriate security measures to protect your personal information against unauthorized access, alteration, or disclosure.\n\n5. Your Rights\nYou have the right to access, correct, or delete your personal information. You can do this within the app settings or by contacting support.\n\n6. Contact Us\nIf you have questions about this Privacy Policy, please contact us at contact@eventzone.pro.',
  'Full Name': 'Full Name',
  'Job Title': 'Job Title',
  'Address': 'Address',
  'Company Website': 'Company Website',
  'Phone Number': 'Phone Number',
  'Email': 'Email',
  'Link': 'Link',
  'LinkedIn': 'LinkedIn',
  'Instagram': 'Instagram',
  'X': 'X',
  'Calendly': 'Calendly',
  'Facebook': 'Facebook',
  'Threads': 'Threads',
  'YouTube': 'YouTube',
  'WhatsApp': 'WhatsApp',
  'Snapchat': 'Snapchat',
  'TikTok': 'TikTok',
  'GitHub': 'GitHub',
  'Yelp': 'Yelp',
  'Venmo': 'Venmo',
  'Scan QR': 'Scan QR',
  'My QR Code': 'My QR Code',
  'Connect directly': 'Connect directly',
  'Show to others': 'Show to others',
  'Quick Connect': 'Quick Connect',
  'Share your profile or scan a colleague': 'Share your profile or scan a colleague',
  'Position the QR Code within the frame': 'Position the QR Code within the frame',
  'Position the Business Card within the frame': 'Position the Business Card within the frame',
  'Processing text recognition...': 'Processing text recognition...',
  'QR Code': 'QR Code',
  'Business Card': 'Business Card'
};

const french = {
  'terms_content': '1. Acceptation des Conditions\nEn accédant ou en utilisant l\'application Eventzone, vous acceptez d\'être lié par ces Conditions d\'Utilisation. Si vous n\'acceptez pas, veuillez ne pas utiliser le service.\n\n2. Description du Service\nEventzone est une plateforme de réseautage B2B conçue pour aider les professionnels à se connecter lors d\'événements.\n\n3. Responsabilités de l\'Utilisateur\nVous êtes responsable de maintenir la confidentialité de votre compte et de toutes les activités qui se produisent sous votre compte. Vous acceptez de ne pas utiliser le service à des fins illégales ou non autorisées.\n\n4. Abonnements\nUn abonnement actif est requis pour accepter continuellement de nouvelles connexions et scanner des badges. Les abonnements peuvent être achetés dans l\'application.\n\n5. Résiliation\nNous nous réservons le droit de suspendre ou de résilier votre compte à tout moment en cas de violation de ces Conditions.\n\n6. Modifications des Conditions\nNous pouvons mettre à jour ces conditions de temps à autre. L\'utilisation continue de l\'application constitue l\'acceptation de tout changement.',
  'privacy_content': '1. Informations que nous collectons\nNous collectons les informations que vous nous fournissez directement, telles que votre nom, titre de poste, entreprise, email et liens sociaux.\n\n2. Comment nous utilisons les informations\nNous utilisons les informations que nous collectons pour fournir, maintenir et améliorer nos services, et faciliter les connexions.\n\n3. Partage d\'informations\nLes informations de votre profil public sont partagées avec d\'autres utilisateurs lorsqu\'ils scannent votre code QR. Nous ne vendons pas vos informations personnelles.\n\n4. Sécurité des données\nNous mettons en œuvre des mesures de sécurité appropriées pour protéger vos informations personnelles.\n\n5. Vos droits\nVous avez le droit d\'accéder, de corriger ou de supprimer vos informations personnelles dans les paramètres de l\'application.\n\n6. Nous contacter\nSi vous avez des questions sur cette Politique de Confidentialité, veuillez nous contacter à contact@eventzone.pro.',
  'Full Name': 'Nom Complet',
  'Job Title': 'Poste',
  'Address': 'Adresse',
  'Company Website': 'Site Web de l\'Entreprise',
  'Phone Number': 'Numéro de Téléphone',
  'Email': 'Email',
  'Link': 'Lien',
  'LinkedIn': 'LinkedIn',
  'Instagram': 'Instagram',
  'X': 'X',
  'Calendly': 'Calendly',
  'Facebook': 'Facebook',
  'Threads': 'Threads',
  'YouTube': 'YouTube',
  'WhatsApp': 'WhatsApp',
  'Snapchat': 'Snapchat',
  'TikTok': 'TikTok',
  'GitHub': 'GitHub',
  'Yelp': 'Yelp',
  'Venmo': 'Venmo',
  'Scan QR': 'Scanner le QR',
  'My QR Code': 'Mon Code QR',
  'Connect directly': 'Connectez-vous directement',
  'Show to others': 'Montrez aux autres',
  'Quick Connect': 'Connexion Rapide',
  'Share your profile or scan a colleague': 'Partagez votre profil ou scannez un collègue',
  'Position the QR Code within the frame': 'Placez le code QR dans le cadre',
  'Position the Business Card within the frame': 'Placez la carte de visite dans le cadre',
  'Processing text recognition...': 'Traitement de la reconnaissance de texte...',
  'QR Code': 'Code QR',
  'Business Card': 'Carte de Visite'
};

const arabic = {
  'terms_content': '1. قبول الشروط\nمن خلال الوصول إلى أو استخدام تطبيق Eventzone، فإنك توافق على الالتزام بشروط الخدمة هذه. إذا كنت لا توافق، يرجى عدم استخدام الخدمة.\n\n2. وصف الخدمة\nEventzone هي منصة تواصل B2B مصممة لمساعدة المحترفين على التواصل في الفعاليات.\n\n3. مسؤوليات المستخدم\nأنت مسؤول عن الحفاظ على سرية حسابك وعن جميع الأنشطة التي تحدث بموجب حسابك. توافق على عدم استخدام الخدمة لأي غرض غير قانوني أو غير مصرح به.\n\n4. الاشتراكات\nمطلوب اشتراك نشط لقبول اتصالات جديدة باستمرار ومسح الشارات. يمكن شراء الاشتراكات داخل التطبيق وتخضع للتسعير المدرج في وقت الشراء.\n\n5. الإنهاء\nنحتفظ بالحق في تعليق أو إنهاء حسابك في أي وقت لانتهاكات هذه الشروط.\n\n6. تغييرات الشروط\nقد نقوم بتحديث هذه الشروط من وقت لآخر. الاستخدام المستمر للتطبيق يشكل قبولًا لأي تغييرات.',
  'privacy_content': '1. المعلومات التي نجمعها\nنجمع المعلومات التي تقدمها إلينا مباشرة، مثل اسمك والمسمى الوظيفي والشركة والبريد الإلكتروني والروابط الاجتماعية.\n\n2. كيف نستخدم المعلومات\nنستخدم المعلومات التي نجمعها لتقديم خدماتنا والحفاظ عليها وتحسينها، وتسهيل الاتصالات مع المستخدمين الآخرين.\n\n3. مشاركة المعلومات\nتتم مشاركة معلومات ملفك الشخصي العام مع المستخدمين الآخرين عندما يمسحون رمز الاستجابة السريعة (QR) الخاص بك. نحن لا نبيع معلوماتك الشخصية.\n\n4. أمن البيانات\nنقوم بتنفيذ تدابير أمنية مناسبة لحماية معلوماتك الشخصية ضد الوصول أو التغيير أو الإفصاح غير المصرح به.\n\n5. حقوقك\nلديك الحق في الوصول إلى معلوماتك الشخصية أو تصحيحها أو حذفها من خلال إعدادات التطبيق أو عن طريق الاتصال بالدعم.\n\n6. اتصل بنا\nإذا كان لديك أسئلة حول سياسة الخصوصية هذه، يرجى الاتصال بنا على contact@eventzone.pro.',
  'Full Name': 'الاسم الكامل',
  'Job Title': 'المسمى الوظيفي',
  'Address': 'العنوان',
  'Company Website': 'موقع الشركة',
  'Phone Number': 'رقم الهاتف',
  'Email': 'البريد الإلكتروني',
  'Link': 'رابط',
  'LinkedIn': 'لينكد إن',
  'Instagram': 'إنستغرام',
  'X': 'إكس',
  'Calendly': 'كالانْدلي',
  'Facebook': 'فيسبوك',
  'Threads': 'ثريدز',
  'YouTube': 'يوتيوب',
  'WhatsApp': 'واتساب',
  'Snapchat': 'سناب شات',
  'TikTok': 'تيك توك',
  'GitHub': 'جيت هاب',
  'Yelp': 'يِلْب',
  'Venmo': 'فينمو',
  'Scan QR': 'مسح رمز الاستجابة السريعة',
  'My QR Code': 'رمز الاستجابة الخاص بي',
  'Connect directly': 'تواصل مباشرة',
  'Show to others': 'أظهره للآخرين',
  'Quick Connect': 'اتصال سريع',
  'Share your profile or scan a colleague': 'شارك ملفك الشخصي أو امسح بطاقة زميل',
  'Position the QR Code within the frame': 'ضع رمز الاستجابة السريعة (QR) داخل الإطار',
  'Position the Business Card within the frame': 'ضع بطاقة العمل داخل الإطار',
  'Processing text recognition...': 'جارٍ معالجة التعرف على النص...',
  'QR Code': 'رمز الاستجابة السريعة',
  'Business Card': 'بطاقة العمل'
};

const updates = { en: english, fr: french, ar: arabic };

files.forEach(file => {
  const lang = file.split('.')[0];
  const path = 'assets/translations/' + file;
  let data = JSON.parse(fs.readFileSync(path));
  data = { ...data, ...updates[lang] };
  fs.writeFileSync(path, JSON.stringify(data, null, 2));
});
