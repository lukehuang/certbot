"""ACME interfaces."""
import zope.interface

# pylint: disable=no-self-argument,no-method-argument,no-init,inherit-non-class
# pylint: disable=too-few-public-methods


class IJSONSerializable(zope.interface.Interface):
    # pylint: disable=too-few-public-methods
    """JSON serializable object."""

    def to_json():
        """Prepare JSON serializable object.

        :returns: JSON object ready to be serialized. Note, however, that
            this might return other
            :class:`letsencrypt.acme.interfaces.IJSONSerializable`
            objects, that haven't been serialized yet, which is fine as
            long as :func:`letsencrypt.acme.util.dump_ijsonserializable`
            is used.
        :rtype: dict

        """

class IJSONDeserializable(zope.interface.Interface):
    """JSON deserializable class."""

    def from_valid_json(jobj):
        """Deserialize valid JSON object.

        :param jobj: JSON object validated against JSON schema (found in
            schemata/ directory).

        :raises letsencrypt.acme.errors.ValidationError: It might be the
            case that ``jobj`` validates against schema, but still is not
            valid (e.g. unparseable X509 certificate, or wrong padding in
            JOSE base64 encoded string).

        """
