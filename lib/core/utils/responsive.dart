class Responsive {
  const Responsive._();

  static bool isDesktop(double width) => width >= 1100;
  static bool isTablet(double width) => width >= 760;
}
