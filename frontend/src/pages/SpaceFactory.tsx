import { Field, Form, Formik } from "formik"
import { Link } from "react-router-dom"

const SpaceForm: React.FC = () => {
  return (
    <Formik
      initialValues={{ whitelistAddress: "" }}
      onSubmit={({ whitelistAddress }) => console.log(whitelistAddress)}
    >
      {() => (
        <div>
          <Form>
            <Field name="whitelistAddress" />
            <button type="submit">Deploy</button>
          </Form>
        </div>
      )}
    </Formik>
  )
}

const SpaceFactory: React.FC = () => {
  return (
    <div className="spaceFactory">
      <Link to={"/"}> Go back home</Link>
      <h1>Create a space</h1>
      First go to the <Link to={"/whitelist-factory"}>whitelist factory</Link>,
      you will deploy the whitelist. You will get an address from it, paste it
      below to deploy the space.
      <SpaceForm />
    </div>
  )
}

export default SpaceFactory
