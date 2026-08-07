function generateOtp(length = 6) {
  const minimum = 10 ** (length - 1);
  const maximum = 10 ** length - 1;
  return String(Math.floor(minimum + Math.random() * (maximum - minimum + 1)));
}

module.exports = { generateOtp };