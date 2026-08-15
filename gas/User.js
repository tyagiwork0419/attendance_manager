

class User{
  constructor(id, name, passwordHash){
    this.id = id;
    this.name = name;
    this.passwordHash = passwordHash;
  }

  setPasswordHash(hash){
    this.passwordHash = hash;
  }

  checkPassword(password){
    let hash = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, password);

    return hash == this.passwordHash;
  }
}
