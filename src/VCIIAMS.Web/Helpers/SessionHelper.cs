namespace VCIIAMS.Web.Helpers
{
    public static class SessionHelper
    {
        public static string GetUsername()
        {
            return "Hard coded user";
        }

        public static void SetUsername(this ISession session, string username)
        {
            session.SetString("Username", username);
        }
    }
}