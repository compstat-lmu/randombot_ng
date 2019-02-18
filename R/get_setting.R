
if (!exists(".setting.register")) {
  .setting.register <- new.env(parent = emptyenv())
}

# create setting ; warning is printed if this unintentionally overwrites a value.
# @param name [character(1)] setting name
# @param value [any] atomic value to set.
# @param value [logical(1)] if this is FALSE, a warning is given on overwrite
#   (might want to consider changing that to ERROR, but for interactive dev this
#   is enough)
rbn.registerSetting <- function(name, value, overwrite = FALSE) {
  assertString(name)
  assertAtomic(value)
  assertFlag(overwrite)
  if (name %in% names(.setting.register) && !overwrite) {
    warningf("Replacing setting %s value %s -> value %s",
      name, collapse(.setting.register[[name]], ","), collapse(value, ","))
  }
  .setting.register[[name]] <- value
}

# get setting by value, error if not set.
# @param name [character(1)] setting name
# @return [any]
rbn.getSetting <- function(name) {
  assertString(name)
  if (name %nin% names(.setting.register)) {
    stopf("Setting name %s not registered.", name)
  }
  .setting.register[[name]]
}
